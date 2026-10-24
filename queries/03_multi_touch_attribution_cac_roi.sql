-- Step 4: Multi-Model Attribution (First, Last, Linear, Time-Decay) + Ad-Spend ROI & CAC
WITH customer_orders AS (
    SELECT
        user_id,
        order_id,
        sale_price AS revenue,
        created_at AS order_time
    FROM `bigquery-public-data.thelook_ecommerce.order_items`
    WHERE status NOT IN ('Cancelled', 'Returned')
),
user_journey AS (
    SELECT
        e.user_id,
        e.traffic_source AS channel,
        e.created_at AS touch_time,
        co.order_id,
        co.revenue,
        co.order_time,
        -- Har touchpoint ka order_time se kitne din pehle ka difference hai (Time-Decay ke liye)
        TIMESTAMP_DIFF(co.order_time, e.created_at, DAY) AS days_before_order,
        -- First & Last Touch Ranks
        ROW_NUMBER() OVER(PARTITION BY co.order_id ORDER BY e.created_at ASC) AS first_touch_rank,
        ROW_NUMBER() OVER(PARTITION BY co.order_id ORDER BY e.created_at DESC) AS last_touch_rank,
        -- Total touchpoints per conversion (Linear model ke liye)
        COUNT(*) OVER(PARTITION BY co.order_id) AS total_touchpoints
    FROM `bigquery-public-data.thelook_ecommerce.events` e
    JOIN customer_orders co
        ON e.user_id = co.user_id
        AND e.created_at <= co.order_time
    WHERE e.user_id IS NOT NULL
),
channel_weights AS (
    SELECT
        order_id,
        revenue,
        channel,
        -- 1. First Touch: Pehle touchpoint ko 100% credit
        CASE WHEN first_touch_rank = 1 THEN revenue ELSE 0 END AS first_touch_revenue,
        -- 2. Last Touch: Aakhiri touchpoint ko 100% credit
        CASE WHEN last_touch_rank = 1 THEN revenue ELSE 0 END AS last_touch_revenue,
        -- 3. Linear: Har touchpoint ko barabar credit
        (revenue / total_touchpoints) AS linear_revenue,
        -- 4. Time-Decay (7-day half-life): Hal ke touchpoints ko zyada weight: 2^(-days/7)
        POW(2, -days_before_order / 7.0) AS decay_weight
    FROM user_journey
),
decay_normalized AS (
    SELECT
        channel,
        first_touch_revenue,
        last_touch_revenue,
        linear_revenue,
        (revenue * decay_weight / NULLIF(SUM(decay_weight) OVER(PARTITION BY order_id), 0)) AS time_decay_revenue
    FROM channel_weights
),
attribution_summary AS (
    SELECT
        channel,
        ROUND(SUM(first_touch_revenue), 2) AS first_touch_rev,
        ROUND(SUM(last_touch_revenue), 2) AS last_touch_rev,
        ROUND(SUM(linear_revenue), 2) AS linear_rev,
        ROUND(SUM(time_decay_revenue), 2) AS time_decay_rev
    FROM decay_normalized
    GROUP BY channel
),
synthetic_ad_spend AS (
    -- Industry standard marketing spend benchmark for e-commerce
    SELECT 'Search' AS channel, 850000.0 AS ad_spend, 12000 AS acquisitions UNION ALL
    SELECT 'Adwords' AS channel, 600000.0 AS ad_spend, 8500 AS acquisitions UNION ALL
    SELECT 'Facebook' AS channel, 350000.0 AS ad_spend, 5200 AS acquisitions UNION ALL
    SELECT 'Email' AS channel, 120000.0 AS ad_spend, 16000 AS acquisitions UNION ALL
    SELECT 'Organic' AS channel, 90000.0 AS ad_spend, 7000 AS acquisitions UNION ALL
    SELECT 'Display' AS channel, 180000.0 AS ad_spend, 2800 AS acquisitions UNION ALL
    SELECT 'YouTube' AS channel, 220000.0 AS ad_spend, 3100 AS acquisitions
)
SELECT
    a.channel,
    s.ad_spend,
    a.first_touch_rev,
    a.last_touch_rev,
    a.linear_rev,
    a.time_decay_rev,
    ROUND(s.ad_spend / NULLIF(s.acquisitions, 0), 2) AS cac, -- Cost per Acquisition
    ROUND(a.time_decay_rev / NULLIF(s.ad_spend, 0), 2) AS roas_ratio -- Return on Ad Spend (ROI)
FROM attribution_summary a
LEFT JOIN synthetic_ad_spend s ON a.channel = s.channel
ORDER BY a.time_decay_rev DESC;
