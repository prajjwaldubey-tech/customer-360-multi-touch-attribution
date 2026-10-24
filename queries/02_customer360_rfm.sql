-- Step 3: Customer 360 Profile with RFM Segmentation
WITH customer_orders AS (
    SELECT
        user_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(sale_price) AS total_lifetime_spend,
        MAX(created_at) AS last_order_date
    FROM `bigquery-public-data.thelook_ecommerce.order_items`
    WHERE status NOT IN ('Cancelled', 'Returned')
    GROUP BY user_id
),
rfm_calculated AS (
    SELECT
        u.id AS customer_id,
        CONCAT(u.first_name, ' ', u.last_name) AS customer_name,
        u.email,
        u.country,
        u.traffic_source AS acquisition_channel,
        co.total_orders AS frequency,
        ROUND(co.total_lifetime_spend, 2) AS monetary_value,
        DATE_DIFF(DATE('2026-10-24'), DATE(co.last_order_date), DAY) AS recency_days
    FROM `bigquery-public-data.thelook_ecommerce.users` u
    JOIN customer_orders co
        ON u.id = co.user_id
)
SELECT 
    customer_id,
    customer_name,
    country,
    acquisition_channel,
    recency_days,
    frequency,
    monetary_value,
    CASE 
        WHEN frequency >= 3 AND recency_days <= 120 THEN 'VIP / High Value'
        WHEN frequency >= 2 AND recency_days <= 200 THEN 'Loyal Customer'
        WHEN frequency = 1 AND recency_days <= 90 THEN 'New Customer'
        WHEN recency_days > 200 THEN 'At Risk / Churn'
        ELSE 'Regular'
    END AS customer_segment
FROM rfm_calculated
ORDER BY monetary_value DESC
LIMIT 20;
