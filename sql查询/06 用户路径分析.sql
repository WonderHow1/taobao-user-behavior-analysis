# 确定用户行为路径
-- 对用户和商品进行分组，计算用户行为数
DROP VIEW user_behavior_view;
DROP VIEW user_behavior_binary_view;
DROP VIEW user_behavior_path;
DROP VIEW user_behavior_path_num;



CREATE VIEW user_behavior_view AS
SELECT
	user_id,
	item_id,
	COUNT(IF(behavior_type = 'pv', behavior_type , NULL)) 'pv',
	COUNT(IF(behavior_type = 'fav', behavior_type , NULL)) 'fav',
	COUNT(IF(behavior_type = 'cart', behavior_type , NULL)) 'cart',
	COUNT(IF(behavior_type = 'buy', behavior_type , NULL)) 'buy'
FROM temp_behavior  # 采用先前截取的小范围数据
GROUP BY
	user_id,
	item_id;



-- 用户行为二值化
CREATE VIEW user_behavior_binary_view AS
SELECT 
	user_id,
	item_id,
	(CASE WHEN pv > 0 THEN 1 ELSE 0 END) 是否浏览,
	(CASE WHEN fav > 0 THEN 1 ELSE 0 END) 是否收藏,
	(CASE WHEN cart > 0 THEN 1 ELSE 0 END) 是否加购,
	(CASE WHEN buy > 0 THEN 1 ELSE 0 END) 是否购买
FROM user_behavior_view;



-- 路径类型
CREATE VIEW user_behavior_path AS
SELECT
	*,
	CONCAT(是否浏览, 是否收藏, 是否加购, 是否购买) AS 购买路径类型
FROM user_behavior_binary_view
WHERE 是否购买 > 0;



-- 统计各类购买路径数量
CREATE VIEW user_behavior_path_num AS
SELECT
	购买路径类型,
	COUNT(*) 购买路径数量
FROM user_behavior_path
GROUP BY 购买路径类型
ORDER BY 购买路径数量 DESC;



# 行为路径说明
CREATE TABLE user_behavior_path_type
	(
	path_value CHAR(4),
	path_type VARCHAR(40)
	);
	
	


INSERT INTO user_behavior_path_type
VALUES
	('0001', '直接购买'),
	('1001', '浏览→购买'),
	('0101', '收藏→购买'),
	('0011', '加购→购买'),
	('1101', '浏览→收藏→购买'),
	('1011', '浏览→加购→购买'),
	('0111', '收藏+加购→购买'),
	('1111', '浏览→收藏+加购→购买')
	;



# 存储

###################	代码服用，对原表进行处理
-- 对用户和商品进行分组，计算用户行为数
CREATE VIEW user_behavior_view AS
SELECT
	user_id,
	item_id,
	COUNT(IF(behavior_type = 'pv', behavior_type , NULL)) 'pv',
	COUNT(IF(behavior_type = 'fav', behavior_type , NULL)) 'fav',
	COUNT(IF(behavior_type = 'cart', behavior_type , NULL)) 'cart',
	COUNT(IF(behavior_type = 'buy', behavior_type , NULL)) 'buy'
FROM user_behavior  #这里进行改变
GROUP BY
	user_id,
	item_id;



-- 用户行为二值化
CREATE VIEW user_behavior_binary_view AS
SELECT 
	user_id,
	item_id,
	(CASE WHEN pv > 0 THEN 1 ELSE 0 END) 是否浏览,
	(CASE WHEN fav > 0 THEN 1 ELSE 0 END) 是否收藏,
	(CASE WHEN cart > 0 THEN 1 ELSE 0 END) 是否加购,
	(CASE WHEN buy > 0 THEN 1 ELSE 0 END) 是否购买
FROM user_behavior_view;



-- 路径类型
CREATE VIEW user_behavior_path AS
SELECT
	*,
	CONCAT(是否浏览, 是否收藏, 是否加购, 是否购买) AS 购买路径类型
FROM user_behavior_binary_view
WHERE 是否购买 > 0;



-- 统计各类购买路径数量
CREATE VIEW user_behavior_path_num AS
SELECT
	购买路径类型,
	COUNT(*) 购买路径数量
FROM user_behavior_path
GROUP BY 购买路径类型
ORDER BY 购买路径数量 DESC;
###################



CREATE TABLE user_path_result
	(
	path_value CHAR(4),
	path_type VARCHAR(40),
	num INT
	);
	
	

INSERT INTO user_path_result
SELECT 
	t.path_value,
	t.path_type,
	n.购买路径数量
FROM user_behavior_path_num n
JOIN user_behavior_path_type t
ON t.path_value = n.购买路径类型;



SELECT * FROM user_path_result;