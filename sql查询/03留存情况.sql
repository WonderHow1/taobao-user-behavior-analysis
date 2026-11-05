# 留存情况
## 留存率
-- 分组
SELECT
	user_id,
	dates
FROM temp_behavior
GROUP BY 
	user_id,
	dates;
	
	
	
-- 自关联（隐式）
SELECT *
FROM
(
	SELECT user_id, dates
	FROM temp_behavior
	GROUP BY user_id, dates
) a,
(
  SELECT user_id, dates
  FROM temp_behavior
  GROUP BY user_id, dates
) b
WHERE a.user_id = b.user_id;



-- 自关联（JOIN）
SELECT *
FROM
(
	SELECT user_id, dates
	FROM temp_behavior
	GROUP BY user_id, dates
) a
JOIN
(
  SELECT user_id, dates
  FROM temp_behavior
  GROUP BY user_id, dates
) b
ON a.user_id = b.user_id;



-- 筛选
SELECT *
FROM
	(
	SELECT user_id, dates
	FROM temp_behavior
	GROUP BY user_id, dates
	) a
JOIN
	(
  SELECT user_id, dates
  FROM temp_behavior
  GROUP BY user_id, dates
	) b
ON a.user_id = b.user_id
	AND a.dates <= b.dates;



-- 留存数
SELECT
	a.dates,
	COUNT(IF(DATEDIFF(b.dates, a.dates) = 0, b.user_id, NULL)) retention_0, # 留存0天
	COUNT(IF(DATEDIFF(b.dates, a.dates) = 1, b.user_id, NULL)) retention_1 # 留存1天
FROM
	(
	SELECT user_id, dates
	FROM temp_behavior
	GROUP BY user_id, dates
	) a
JOIN
	(
  SELECT user_id, dates
  FROM temp_behavior
  GROUP BY user_id, dates
	) b
ON a.user_id = b.user_id
	AND a.dates <= b.dates
GROUP BY a.dates;



-- 留存率
SELECT
	a.dates,
	COUNT(IF(DATEDIFF(b.dates, a.dates) = 1, b.user_id, NULL)) / COUNT(IF(DATEDIFF(b.dates, a.dates) = 0, b.user_id, NULL)) retention_rate
FROM
	(
	SELECT user_id, dates
	FROM temp_behavior
	GROUP BY user_id, dates
	) a
JOIN
	(
  SELECT user_id, dates
  FROM temp_behavior
  GROUP BY user_id, dates
	) b
ON a.user_id = b.user_id
	AND a.dates <= b.dates
GROUP BY a.dates;



-- 保存结果
CREATE TABLE retention_rate
	(
	dates CHAR(10),
	retention_rate FLOAT
	);

INSERT INTO retention_rate
SELECT
	a.dates,
	COUNT(IF(DATEDIFF(b.dates, a.dates) = 1, b.user_id, NULL)) / COUNT(IF(DATEDIFF(b.dates, a.dates) = 0, b.user_id, NULL)) retention_rate
FROM
	(
	SELECT user_id, dates
	FROM user_behavior
	GROUP BY user_id, dates
	) a
JOIN
	(
  SELECT user_id, dates
  FROM user_behavior
  GROUP BY user_id, dates
	) b
ON a.user_id = b.user_id
	AND a.dates <= b.dates
GROUP BY a.dates;



SELECT *
FROM retention_rate;



## 跳失率
-- 跳失数
SELECT COUNT(*)
FROM
	(
	SELECT user_id
	FROM user_behavior
	GROUP BY user_id
	HAVING COUNT(id) = 1
	) a;



-- 跳失率
SELECT 
	ROUND(
		(SELECT COUNT(*) FROM (SELECT user_id FROM user_behavior GROUP BY user_id HAVING COUNT(id) = 1) a) 
		 / (SELECT SUM(uv) FROM pv_uv_puv) 
		, 6) AS bounce_rate;





