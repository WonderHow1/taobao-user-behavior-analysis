USE taobao_user_operations;



-- 数据概览
DESC user_behavior;
SELECT * FROM user_behavior LIMIT 10;
SELECT COUNT(1) FROM user_behavior; -- 100095424



-- 更改buffer值
SHOW VARIABLES LIKE '%_buffer%';
SET GLOBAL innodb_buffer_pool_size = 4294967296;



-- 添加id主键
ALTER TABLE user_behavior
ADD id INT FIRST;

ALTER TABLE user_behavior
MODIFY id INT PRIMARY KEY AUTO_INCREMENT FIRST;




-- 检查空值
SELECT * FROM user_behavior WHERE user_id IS NULL;
SELECT * FROM user_behavior WHERE item_id IS NULL;
SELECT * FROM user_behavior WHERE category_id IS NULL;
SELECT * FROM user_behavior WHERE behavior_type IS NULL;
SELECT * FROM user_behavior WHERE timestamps IS NULL;




-- 检查重复值
SELECT
	user_id,
	item_id,
	timestamps
FROM user_behavior
GROUP BY
	user_id,
	item_id,
	tim estamps
HAVING count(*) > 1;

-- 去重
DELETE user_behavior
FROM user_behavior,
	(
		SELECT
			user_id,
			item_id,
			timestamps,
			MIN(id) id
		FROM user_behavior
		GROUP BY
			user_id,
			item_id,
			timestamps
		HAVING count(*) > 1
	) t2
WHERE user_behavior.user_id = t2.user_id
	AND user_behavior.item_id = t2.item_id
	AND user_behavior.timestamps = t2.timestamps
	AND user_behavior.id > t2.id;



-- 新增日期：dates times hours
	-- datetimes
ALTER TABLE user_behavior
ADD datetimes TIMESTAMP(0);

UPDATE user_behavior
SET datetimes = FROM_UNIXTIME(timestamps)
WHERE timestamps > 0;

	-- dates times hours
ALTER TABLE user_behavior
ADD dates CHAR(10);
ALTER TABLE user_behavior
ADD times CHAR(8);
ALTER TABLE user_behavior
ADD hours CHAR(2);

UPDATE user_behavior
SET dates = substring(datetimes,1,10);
UPDATE user_behavior
SET times = substring(datetimes,12,8);
UPDATE user_behavior
SET hours = substring(datetimes,12,2);

SELECT * FROM user_behavior WHERE dates IS NULL;
SELECT * FROM user_behavior WHERE times IS NULL;
SELECT * FROM user_behavior WHERE hours IS NULL;

DELETE FROM user_behavior
WHERE dates IS NULL 
	OR times IS NULL 
	OR hours IS NULL;



-- 检测异常值
SELECT MAX(datetimes), MIN(datetimes)
FROM user_behavior;

-- 去除异常值
DELETE FROM user_behavior
WHERE datetimes < '2017-11-25 00:00:00'
	OR datetimes > '2017-12-03 23:59:59';
