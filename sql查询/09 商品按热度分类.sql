-- 按浏览量计算热门商品品类排行
SELECT
	category_id,
	SUM(behavior_type = 'pv') pv_num
FROM temp_behavior
GROUP BY category_id
ORDER BY pv_num DESC
LIMIT 20;



-- 按浏览量计算热门商品排行
SELECT
	item_id,
	SUM(behavior_type = 'pv') pv_num
FROM temp_behavior
GROUP BY item_id
ORDER BY pv_num DESC
LIMIT 20;



-- 计算热门品类商品排行（热门品类中最热门的商品）
SELECT
	category_id,
	item_id,
	品类商品浏览量
FROM
	(
	SELECT
		category_id,
		item_id,
		SUM(behavior_type = 'pv') 品类商品浏览量,
		RANK() OVER 
			(
			PARTITION BY category_id 
			ORDER BY SUM(behavior_type = 'pv') DESC
			) r
	FROM temp_behavior
	GROUP BY
		category_id,
		item_id
	ORDER BY 3 DESC
	) t  -- 用开窗函数给各个品类中的商品进行排序
WHERE t.r = 1  -- 筛选各品类中最热门的商品
GROUP BY
	category_id,
	item_id
ORDER BY 品类商品浏览量 DESC
LIMIT 20;



-- 存储
CREATE TABLE popular_categories
	(
	category_id INT,
	pv INT
	);

CREATE TABLE popular_items
	(
	item_id INT,
	pv INT
	);

CREATE TABLE popular_categories_items
	(
	category_id INT,
	item_id INT,
	pv INT
	);




INSERT INTO popular_categories
SELECT
	category_id,
	SUM(behavior_type = 'pv') pv_num
FROM user_behavior
GROUP BY category_id
ORDER BY pv_num DESC
LIMIT 20;



INSERT INTO popular_items
SELECT
	item_id,
	SUM(behavior_type = 'pv') pv_num
FROM user_behavior
GROUP BY item_id
ORDER BY pv_num DESC
LIMIT 20;



INSERT INTO popular_categories_items
SELECT
	category_id,
	item_id,
	品类商品浏览量
FROM
	(
	SELECT
		category_id,
		item_id,
		SUM(behavior_type = 'pv') 品类商品浏览量,
		RANK() OVER 
			(
			PARTITION BY category_id 
			ORDER BY SUM(behavior_type = 'pv') DESC
			) r
	FROM user_behavior
	GROUP BY
		category_id,
		item_id
	ORDER BY 3 DESC
	) t
WHERE t.r = 1 
GROUP BY
	category_id,
	item_id
ORDER BY 品类商品浏览量 DESC
LIMIT 20;



SELECT * FROM popular_categories;

SELECT * FROM popular_items;

SELECT * FROM popular_categories_items;

