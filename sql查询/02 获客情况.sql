-- 创建临时表
CREATE TABLE temp_behavior LIKE user_behavior;



-- 截取数据
INSERT INTO temp_behavior
SELECT * FROM user_behavior LIMIT 100000;

SELECT * FROM temp_behavior;



# 获客情况
-- pv 页面浏览量
SELECT
	dates,
	COUNT(*) AS pv
FROM temp_behavior
WHERE behavior_type = 'pv'
GROUP BY dates;



-- uv 独立访客数
SELECT
	dates,
	COUNT(DISTINCT user_id) AS uv
FROM temp_behavior
WHERE behavior_type = 'pv'
GROUP BY dates;



-- pv/uv 浏览深度（人均pv）
SELECT
	dates,
	COUNT(*) AS pv,
	COUNT(DISTINCT user_id) AS uv,
	ROUND(COUNT(*)/COUNT(DISTINCT user_id), 1) AS 'pv/uv'
FROM temp_behavior
WHERE behavior_type = 'pv'
GROUP BY dates;



-- 保存结果
CREATE TABLE pv_uv_puv
(
	dates CHAR(10),
	pv INT(9),
	uv INT(9),
	puv DECIMAL(10, 1)
);



INSERT INTO pv_uv_puv
SELECT
	dates,
	COUNT(*) AS pv,
	COUNT(DISTINCT user_id) AS uv,
	ROUND(COUNT(*)/COUNT(DISTINCT user_id), 1) AS 'pv/uv'
FROM user_behavior
WHERE behavior_type = 'pv'
GROUP BY dates;

SELECT * FROM pv_uv_puv;







