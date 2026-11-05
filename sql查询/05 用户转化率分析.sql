-- 统计各个行为的用户数量
SELECT
	behavior_type,
	COUNT(DISTINCT(user_id)) AS user_num
FROM temp_behavior
GROUP BY behavior_type
ORDER BY user_num DESC;



CREATE TABLE behavior_user_num
	(
	behavior_type VARCHAR(5),
	user_num INT
	);



INSERT INTO behavior_user_num
SELECT
	behavior_type,
	COUNT(DISTINCT(user_id)) AS user_num
FROM user_behavior
GROUP BY behavior_type
ORDER BY user_num DESC;



SELECT * FROM behavior_user_num;

SELECT 672404 / 984105 AS 'buy/pv';



-- 统计各类行为的数量
SELECT
	behavior_type,
	COUNT(*) AS behavior_num
FROM temp_behavior
GROUP BY behavior_type
ORDER BY behavior_num DESC;



CREATE TABLE behavior_num
 (
 behavior_type VARCHAR(5),
 behavior_num INT
 );



INSERT INTO behavior_num
SELECT
	behavior_type,
	COUNT(*) AS behavior_num
FROM user_behavior
GROUP BY behavior_type
ORDER BY behavior_num DESC;



SELECT * FROM behavior_num;

SELECT 2015807 / 89660668 AS 'buy/uv';

SELECT 2888258 / 89660668 AS 'fav/uv';




