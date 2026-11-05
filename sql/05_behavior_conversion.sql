USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
CREATE TABLE IF NOT EXISTS behavior_user_num (
    behavior_type VARCHAR(5) NOT NULL PRIMARY KEY,
    user_num BIGINT UNSIGNED NOT NULL
);
TRUNCATE TABLE behavior_user_num;
INSERT INTO behavior_user_num (behavior_type,user_num)
SELECT 'pv',SUM(pv>0) FROM user_summary UNION ALL
SELECT 'fav',SUM(fav>0) FROM user_summary UNION ALL
SELECT 'cart',SUM(cart>0) FROM user_summary UNION ALL
SELECT 'buy',SUM(buy>0) FROM user_summary;

CREATE TABLE IF NOT EXISTS behavior_num (
    behavior_type VARCHAR(5) NOT NULL PRIMARY KEY,
    behavior_num BIGINT UNSIGNED NOT NULL
);
TRUNCATE TABLE behavior_num;
INSERT INTO behavior_num (behavior_type,behavior_num)
SELECT 'pv',SUM(pv) FROM user_summary UNION ALL
SELECT 'fav',SUM(fav) FROM user_summary UNION ALL
SELECT 'cart',SUM(cart) FROM user_summary UNION ALL
SELECT 'buy',SUM(buy) FROM user_summary;
SELECT * FROM behavior_user_num ORDER BY user_num DESC;
SELECT * FROM behavior_num ORDER BY behavior_num DESC;

-- The buying-user numerator is restricted to the browsing-user denominator.
-- The count ratio is a separate metric, not an individual conversion chance.
SELECT SUM(pv>0 AND buy>0) AS browsing_buyers,
       SUM(pv>0) AS browsing_users,
       SUM(pv>0 AND buy>0)*1e0/NULLIF(SUM(pv>0),0) AS browsing_buyers_share,
       SUM(buy)*1e0/NULLIF(SUM(pv),0) AS purchase_event_pv_ratio,
       SUM(buy>0) AS buyers,
       SUM(buy>=2) AS repeat_purchase_event_users,
       SUM(buy>=2)*1e0/NULLIF(SUM(buy>0),0) AS repeat_purchase_event_user_share
FROM user_summary;
