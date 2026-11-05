-- User behavior intersections over the nine-day window.
-- Neither time order nor the same item is required by this definition.
USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
CREATE TABLE IF NOT EXISTS funnel (
    step_id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    step VARCHAR(40) NOT NULL,
    funnel_users BIGINT UNSIGNED NOT NULL,
    step_conversion_rate DECIMAL(18,10) NULL,
    overall_conversion_rate DECIMAL(18,10) NULL
);
TRUNCATE TABLE funnel;
INSERT INTO funnel
    (step_id,step,funnel_users,step_conversion_rate,overall_conversion_rate)
WITH counts AS (
    SELECT SUM(pv>0) AS pv_users,
           SUM(pv>0 AND (fav>0 OR cart>0)) AS intent_users,
           SUM(pv>0 AND (fav>0 OR cart>0) AND buy>0) AS buy_users
    FROM user_summary
), steps AS (
    SELECT 1 AS step_id,'浏览' AS step,pv_users AS users,
           pv_users AS previous_users,pv_users AS first_users FROM counts
    UNION ALL
    SELECT 2,'收藏或加购',intent_users,pv_users,pv_users FROM counts
    UNION ALL
    SELECT 3,'购买',buy_users,intent_users,pv_users FROM counts
)
SELECT step_id,step,users,users*1e0/NULLIF(previous_users,0),
       users*1e0/NULLIF(first_users,0) FROM steps;
-- Ratios are stored as 0-1 values; percentage formatting belongs to display.
SELECT step_id,step,funnel_users,
       ROUND(step_conversion_rate*100,2) AS step_conversion_percent,
       ROUND(overall_conversion_rate*100,2) AS overall_conversion_percent
FROM funnel ORDER BY step_id;
