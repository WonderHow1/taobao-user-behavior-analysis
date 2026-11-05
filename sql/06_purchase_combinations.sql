-- Period-level behavior combinations per purchasing user-item pair.
-- A combination does not establish chronological order.
USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
CREATE TABLE IF NOT EXISTS purchase_pairs (
    user_id INT UNSIGNED NOT NULL,
    item_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id,item_id)
) ENGINE=InnoDB;
TRUNCATE TABLE purchase_pairs;
INSERT INTO purchase_pairs (user_id,item_id)
SELECT user_id,item_id FROM user_behavior_clean
WHERE behavior_type='buy' GROUP BY user_id,item_id;

CREATE TABLE IF NOT EXISTS purchase_pair_flags (
    user_id INT UNSIGNED NOT NULL,
    item_id INT UNSIGNED NOT NULL,
    has_pv TINYINT UNSIGNED NOT NULL,
    has_fav TINYINT UNSIGNED NOT NULL,
    has_cart TINYINT UNSIGNED NOT NULL,
    buy_events BIGINT UNSIGNED NOT NULL,
    first_pv BIGINT NULL,
    first_intent BIGINT NULL,
    first_buy BIGINT NOT NULL,
    PRIMARY KEY (user_id,item_id)
) ENGINE=InnoDB;
TRUNCATE TABLE purchase_pair_flags;
INSERT INTO purchase_pair_flags
    (user_id,item_id,has_pv,has_fav,has_cart,buy_events,first_pv,first_intent,first_buy)
SELECT b.user_id,b.item_id,MAX(b.behavior_type='pv'),MAX(b.behavior_type='fav'),
       MAX(b.behavior_type='cart'),SUM(b.behavior_type='buy'),
       MIN(CASE WHEN b.behavior_type='pv' THEN b.timestamps END),
       MIN(CASE WHEN b.behavior_type IN ('fav','cart') THEN b.timestamps END),
       MIN(CASE WHEN b.behavior_type='buy' THEN b.timestamps END)
FROM user_behavior_clean b
JOIN purchase_pairs p ON b.user_id=p.user_id AND b.item_id=p.item_id
GROUP BY b.user_id,b.item_id;

CREATE TABLE IF NOT EXISTS user_path_result (
    path_value CHAR(4) NOT NULL PRIMARY KEY,
    path_type VARCHAR(50) NOT NULL,
    num BIGINT UNSIGNED NOT NULL,
    pair_share DECIMAL(18,10) NOT NULL,
    buy_events BIGINT UNSIGNED NOT NULL
);
TRUNCATE TABLE user_path_result;
INSERT INTO user_path_result (path_value,path_type,num,pair_share,buy_events)
WITH combinations AS (
    SELECT CONCAT(has_pv,has_fav,has_cart,'1') AS path_value,
           COUNT(*) AS num,SUM(buy_events) AS buy_events
    FROM purchase_pair_flags GROUP BY has_pv,has_fav,has_cart
)
SELECT path_value,
       CASE path_value
         WHEN '0001' THEN '仅购买'
         WHEN '1001' THEN '浏览＋购买'
         WHEN '0101' THEN '收藏＋购买'
         WHEN '0011' THEN '加购＋购买'
         WHEN '1101' THEN '浏览＋收藏＋购买'
         WHEN '1011' THEN '浏览＋加购＋购买'
         WHEN '0111' THEN '收藏＋加购＋购买'
         WHEN '1111' THEN '浏览＋收藏＋加购＋购买'
       END,
       num,num*1e0/NULLIF(SUM(num) OVER(),0),buy_events
FROM combinations;
SELECT * FROM user_path_result ORDER BY num DESC;

-- Supplemental check demonstrating why arrows cannot imply sequence.
SELECT COUNT(*) AS pv_buy_pairs,
       SUM(first_buy<first_pv) AS first_buy_before_first_pv,
       SUM(first_buy<first_pv)*1e0/NULLIF(COUNT(*),0) AS reverse_first_event_share
FROM purchase_pair_flags WHERE has_pv=1 AND has_fav=0 AND has_cart=0;
