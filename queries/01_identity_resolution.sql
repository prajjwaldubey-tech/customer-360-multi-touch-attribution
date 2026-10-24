-- Step 1: Session Level Identity Resolution & Traffic Attribution
WITH session_mapping AS (
    SELECT
        session_id,
        user_id,
        traffic_source,
        MIN(created_at) AS session_start_time,
        MAX(created_at) AS session_end_time,
        COUNT(id) AS total_page_views,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchased
    FROM `bigquery-public-data.thelook_ecommerce.events`
    WHERE user_id IS NOT NULL
    GROUP BY session_id, user_id, traffic_source
)
SELECT 
    session_id,
    user_id,
    traffic_source,
    session_start_time,
    total_page_views,
    has_purchased
FROM session_mapping
ORDER BY session_start_time DESC
LIMIT 20;
