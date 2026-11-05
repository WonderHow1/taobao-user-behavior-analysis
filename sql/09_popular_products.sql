USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
CREATE TABLE IF NOT EXISTS popular_categories (
    category_id INT UNSIGNED NOT NULL PRIMARY KEY,pv BIGINT UNSIGNED NOT NULL
);
CREATE TABLE IF NOT EXISTS popular_items (
    item_id INT UNSIGNED NOT NULL PRIMARY KEY,pv BIGINT UNSIGNED NOT NULL
);
CREATE TABLE IF NOT EXISTS popular_categories_items (
    category_id INT UNSIGNED NOT NULL,item_id INT UNSIGNED NOT NULL,
    pv BIGINT UNSIGNED NOT NULL,PRIMARY KEY(category_id,item_id)
);
TRUNCATE TABLE popular_categories;
TRUNCATE TABLE popular_items;
TRUNCATE TABLE popular_categories_items;
INSERT INTO popular_categories (category_id,pv)
SELECT category_id,SUM(behavior_type='pv') AS pv
FROM user_behavior_clean GROUP BY category_id
ORDER BY pv DESC,category_id LIMIT 20;
INSERT INTO popular_items (item_id,pv)
SELECT item_id,SUM(behavior_type='pv') AS pv
FROM user_behavior_clean GROUP BY item_id
ORDER BY pv DESC,item_id LIMIT 20;

-- Some item IDs occur in more than one category. Retain the event's category.
-- RANK keeps ties for each category's first place, then the final result takes
-- the first 20 category-item winners by PV, with deterministic tie-breaks.
INSERT INTO popular_categories_items (category_id,item_id,pv)
WITH category_item_counts AS (
    SELECT category_id,item_id,SUM(behavior_type='pv') AS pv
    FROM user_behavior_clean GROUP BY category_id,item_id
), ranked AS (
    SELECT *,RANK() OVER(PARTITION BY category_id ORDER BY pv DESC) AS pv_rank
    FROM category_item_counts
)
SELECT category_id,item_id,pv FROM ranked WHERE pv_rank=1
ORDER BY pv DESC,category_id,item_id LIMIT 20;
SELECT * FROM popular_categories ORDER BY pv DESC,category_id;
SELECT * FROM popular_items ORDER BY pv DESC,item_id;
SELECT * FROM popular_categories_items ORDER BY pv DESC,category_id,item_id;
