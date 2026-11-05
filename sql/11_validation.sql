-- Fixed-source control totals for the documented full dataset.
-- This script reads results only. A changed source requires new expectations.
USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
WITH checks AS (
    SELECT 'raw_rows' AS metric,COUNT(*) AS actual,100150807 AS expected FROM user_behavior
    UNION ALL SELECT 'clean_rows',COUNT(*),100095178 FROM user_behavior_clean
    UNION ALL SELECT 'users',COUNT(*),987991 FROM user_summary
    UNION ALL SELECT 'pv',SUM(pv),89660668 FROM user_summary
    UNION ALL SELECT 'fav',SUM(fav),2888258 FROM user_summary
    UNION ALL SELECT 'cart',SUM(cart),5530445 FROM user_summary
    UNION ALL SELECT 'buy',SUM(buy),2015807 FROM user_summary
    UNION ALL SELECT 'daily_pv',SUM(pv),89660668 FROM pv_uv_puv
    UNION ALL SELECT 'date_hour_pv',SUM(pv),89660668 FROM date_hour_behavior
    UNION ALL SELECT 'date_hour_buy',SUM(buy),2015807 FROM date_hour_behavior
    UNION ALL SELECT 'retention_rows',COUNT(*),9 FROM retention_rate
    UNION ALL SELECT 'retention_final_day_rows',COUNT(*),1 FROM retention_rate WHERE dates='2017-12-03'
    UNION ALL SELECT 'funnel_rows',COUNT(*),3 FROM funnel
    UNION ALL SELECT 'funnel_browsers',COALESCE(SUM(funnel_users),0),984105 FROM funnel WHERE step_id=1
    UNION ALL SELECT 'funnel_intent',COALESCE(SUM(funnel_users),0),855498 FROM funnel WHERE step_id=2
    UNION ALL SELECT 'funnel_buyers',COALESCE(SUM(funnel_users),0),600278 FROM funnel WHERE step_id=3
    UNION ALL SELECT 'purchasing_pairs',SUM(num),1926027 FROM user_path_result
    UNION ALL SELECT 'pair_purchase_events',SUM(buy_events),2015807 FROM user_path_result
    UNION ALL SELECT 'rf_buyers',COUNT(*),672404 FROM rfm_model
    UNION ALL SELECT 'rf_classes',COUNT(DISTINCT class),4 FROM rfm_model
    UNION ALL SELECT 'rf_value_users',COUNT(*),273128 FROM rfm_model WHERE class='价值用户'
    UNION ALL SELECT 'rf_boundary_users',COUNT(*),0 FROM rfm_model WHERE class='边界待分类'
    UNION ALL SELECT 'items',COUNT(*),4161138 FROM item_detail
    UNION ALL SELECT 'categories',COUNT(*),9437 FROM category_detail
    UNION ALL SELECT 'item_pv',SUM(pv),89660668 FROM item_detail
    UNION ALL SELECT 'item_buy',SUM(buy),2015807 FROM item_detail
    UNION ALL SELECT 'category_pv',SUM(pv),89660668 FROM category_detail
    UNION ALL SELECT 'category_buy',SUM(buy),2015807 FROM category_detail
)
SELECT metric,actual,expected,CASE WHEN actual=expected THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks ORDER BY metric;

-- Invariants independent of fixed source totals; each violation count is zero.
SELECT 'retention_last_day_must_be_null' AS check_name,COUNT(*) AS violations
FROM retention_rate WHERE dates='2017-12-03' AND retention_rate IS NOT NULL
UNION ALL
SELECT 'retention_observable_rate_missing',COUNT(*) FROM retention_rate
WHERE dates<'2017-12-03' AND retention_rate IS NULL
UNION ALL
SELECT 'retention_rate_bounds',COUNT(*) FROM retention_rate
WHERE retention_rate<0 OR retention_rate>1
UNION ALL
SELECT 'funnel_rate_bounds',COUNT(*) FROM funnel
WHERE step_conversion_rate<0 OR step_conversion_rate>1
   OR overall_conversion_rate<0 OR overall_conversion_rate>1
UNION ALL
SELECT 'item_buyer_denominator',COUNT(*) FROM item_detail WHERE buyers>users
UNION ALL
SELECT 'category_buyer_denominator',COUNT(*) FROM category_detail WHERE buyers>users;
