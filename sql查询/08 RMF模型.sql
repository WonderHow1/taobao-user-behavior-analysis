# 最近购买时间R、购买次数F（原数据表没有交易金额数据，故不考虑M维度）
SELECT 
	user_id,
	MAX(dates) 最近购买日期,
	COUNT(behavior_type) 购买次数
FROM temp_behavior
WHERE behavior_type = 'buy'
GROUP BY user_id
ORDER BY 2 DESC, 3 DESC;



CREATE TABLE rfm_model
	(
	user_id INT,
	recency CHAR(10),
	frequency int
	);
	
	
	
INSERT INTO rfm_model
SELECT 
	user_id,
	MAX(dates) 最近购买日期,
	COUNT(behavior_type) 购买次数
FROM user_behavior
WHERE behavior_type = 'buy'
GROUP BY user_id
ORDER BY 2 DESC, 3 DESC;



# 用户分层
ALTER TABLE rfm_model
ADD COLUMN r_score INT,
ADD COLUMN f_score INT;



UPDATE rfm_model
SET r_score =
CASE
	WHEN recency = '2017-12-03' THEN 5
	WHEN recency IN ('2017-12-01', '2017-12-02') THEN 4
	WHEN recency IN ('2017-11-29', '2017-11-30') THEN 3
	WHEN recency IN ('2017-11-27', '2017-11-28') THEN 2
	ELSE 1
END;

UPDATE rfm_model a
JOIN 
(
	SELECT
		user_id,
		NTILE(5) OVER (ORDER BY frequency) AS score
  FROM rfm_model
) b
ON a.user_id = b.user_id
SET a.f_score = b.score;



SET @r_avg = NULL;
SET @f_avg = NULL;

SELECT AVG(r_score) INTO @r_avg
FROM rfm_model;
SELECT AVG(f_score) INTO @f_avg
FROM rfm_model;



SELECT
	*,
	(
	CASE
		WHEN r_score > @r_avg AND f_score > @f_avg THEN '价值用户'
		WHEN r_score > @r_avg AND f_score < @f_avg THEN '发展用户'
		WHEN r_score < @r_avg AND f_score > @f_avg THEN '保持用户'
		WHEN r_score < @r_avg AND f_score < @f_avg THEN '挽留用户'
	END 
	) class
FROM rfm_model;



ALTER TABLE rfm_model
ADD COLUMN class VARCHAR(40);



UPDATE rfm_model
SET class = 
CASE
		WHEN r_score > @r_avg AND f_score > @f_avg THEN '价值用户'
		WHEN r_score > @r_avg AND f_score < @f_avg THEN '发展用户'
		WHEN r_score < @r_avg AND f_score > @f_avg THEN '保持用户'
		WHEN r_score < @r_avg AND f_score < @f_avg THEN '挽留用户'
END;



SELECT
    SUM(class = '价值用户') AS 价值用户,
    SUM(class = '发展用户') AS 发展用户,
    SUM(class = '保持用户') AS 保持用户,
    SUM(class = '挽留用户') AS 挽留用户
FROM rfm_model;



SELECT
    f_score,
    COUNT(*) AS 用户数,
    MIN(frequency) AS 最低购买次数,
    MAX(frequency) AS 最高购买次数
FROM rfm_model
GROUP BY f_score
ORDER BY f_score;



SELECT
    frequency AS 购买次数,
    COUNT(*) AS 用户数
FROM rfm_model
GROUP BY frequency
ORDER BY frequency;
