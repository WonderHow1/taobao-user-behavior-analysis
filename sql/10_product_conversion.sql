-- Buyer share = distinct buyers / distinct users with ANY recorded behavior.
-- It is not a strict browsing-user or chronological conversion rate.
USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
CREATE TABLE IF NOT EXISTS item_detail (
    item_id INT UNSIGNED NOT NULL PRIMARY KEY,
    pv BIGINT UNSIGNED NOT NULL,fav BIGINT UNSIGNED NOT NULL,
    cart BIGINT UNSIGNED NOT NULL,buy BIGINT UNSIGNED NOT NULL,
    users BIGINT UNSIGNED NOT NULL,buyers BIGINT UNSIGNED NOT NULL,
    user_buy_rate DECIMAL(18,10) NULL
);
CREATE TABLE IF NOT EXISTS category_detail (
    category_id INT UNSIGNED NOT NULL PRIMARY KEY,
    pv BIGINT UNSIGNED NOT NULL,fav BIGINT UNSIGNED NOT NULL,
    cart BIGINT UNSIGNED NOT NULL,buy BIGINT UNSIGNED NOT NULL,
    users BIGINT UNSIGNED NOT NULL,buyers BIGINT UNSIGNED NOT NULL,
    user_buy_rate DECIMAL(18,10) NULL
);
TRUNCATE TABLE item_detail;
TRUNCATE TABLE category_detail;
INSERT INTO item_detail (item_id,pv,fav,cart,buy,users,buyers,user_buy_rate)
SELECT item_id,SUM(behavior_type='pv'),SUM(behavior_type='fav'),
       SUM(behavior_type='cart'),SUM(behavior_type='buy'),COUNT(DISTINCT user_id),
       COUNT(DISTINCT CASE WHEN behavior_type='buy' THEN user_id END),
       COUNT(DISTINCT CASE WHEN behavior_type='buy' THEN user_id END)*1e0
           /NULLIF(COUNT(DISTINCT user_id),0)
FROM user_behavior_clean GROUP BY item_id;
INSERT INTO category_detail (category_id,pv,fav,cart,buy,users,buyers,user_buy_rate)
SELECT category_id,SUM(behavior_type='pv'),SUM(behavior_type='fav'),
       SUM(behavior_type='cart'),SUM(behavior_type='buy'),COUNT(DISTINCT user_id),
       COUNT(DISTINCT CASE WHEN behavior_type='buy' THEN user_id END),
       COUNT(DISTINCT CASE WHEN behavior_type='buy' THEN user_id END)*1e0
           /NULLIF(COUNT(DISTINCT user_id),0)
FROM user_behavior_clean GROUP BY category_id;

-- Supplemental rankings retain denominators and explicit sample thresholds.
SELECT * FROM item_detail WHERE users>=100
ORDER BY user_buy_rate DESC,users DESC,item_id LIMIT 20;
SELECT * FROM category_detail WHERE users>=1000
ORDER BY user_buy_rate DESC,users DESC,category_id LIMIT 20;

-- Supplemental cross-ranking: browsing popularity need not match purchases.
WITH ranks AS (
    SELECT *,RANK() OVER(ORDER BY pv DESC) AS pv_rank,
           RANK() OVER(ORDER BY buy DESC) AS buy_rank
    FROM item_detail
)
SELECT item_id,pv,buy,users,buyers,user_buy_rate,pv_rank,buy_rank
FROM ranks WHERE pv_rank<=20 OR buy_rank<=20 ORDER BY pv_rank,item_id;
WITH top_pv AS (
    SELECT item_id FROM item_detail ORDER BY pv DESC,item_id LIMIT 20
), top_buy AS (
    SELECT item_id FROM item_detail ORDER BY buy DESC,item_id LIMIT 20
)
SELECT COUNT(*) AS overlapping_top20_items FROM top_pv JOIN top_buy USING(item_id);
