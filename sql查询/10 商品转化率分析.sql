-- 商品转化率
SELECT
	item_id,
	SUM(behavior_type = 'pv') pv,
	SUM(behavior_type = 'fav') fav,
	SUM(behavior_type = 'cart') cart,
	SUM(behavior_type = 'buy') buy,
	COUNT(DISTINCT IF(behavior_type = 'buy', user_id, NULL)) / COUNT(DISTINCT user_id) '商品转化率'
FROM temp_behavior
GROUP BY item_id
ORDER BY 商品转化率 DESC;



CREATE TABLE item_detail
	(
	item_id INT,
	pv INT,
	fav INT,
	cart INT,
	buy INT,
	user_buy_rate FLOAT
	);



INSERT INTO item_detail
SELECT
	item_id,
	SUM(behavior_type = 'pv') pv,
	SUM(behavior_type = 'fav') fav,
	SUM(behavior_type = 'cart') cart,
	SUM(behavior_type = 'buy') buy,
	COUNT(DISTINCT IF(behavior_type = 'buy', user_id, NULL)) / COUNT(DISTINCT user_id) '商品转化率'
FROM user_behavior
GROUP BY item_id
ORDER BY 商品转化率 DESC;



SELECT * FROM item_detail;



-- 品类转化率
SELECT
	category_id,
	SUM(behavior_type = 'pv') pv,
	SUM(behavior_type = 'fav') fav,
	SUM(behavior_type = 'cart') cart,
	SUM(behavior_type = 'buy') buy,
	COUNT(DISTINCT IF(behavior_type = 'buy', user_id, NULL)) / COUNT(DISTINCT user_id) '品类转化率'
FROM temp_behavior
GROUP BY category_id
ORDER BY 品类转化率 DESC;



CREATE TABLE category_detail
	(
	category_id INT,
	pv INT,
	fav INT,
	cart INT,
	buy INT,
	user_buy_rate FLOAT
	);
	

	
INSERT INTO category_detail
SELECT
	category_id,
	SUM(behavior_type = 'pv') pv,
	SUM(behavior_type = 'fav') fav,
	SUM(behavior_type = 'cart') cart,
	SUM(behavior_type = 'buy') buy,
	COUNT(DISTINCT IF(behavior_type = 'buy', user_id, NULL)) / COUNT(DISTINCT user_id) '品类转化率'
FROM user_behavior
GROUP BY category_id
ORDER BY 品类转化率 DESC;



SELECT * FROM category_detail;
