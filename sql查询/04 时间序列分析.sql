-- 统计日期-时间的行为
SELECT
	dates,
	hours,
	COUNT(if(behavior_type = 'pv', behavior_type, NULL)) AS pv,
	COUNT(if(behavior_type = 'cart', behavior_type, NULL)) AS cart,
	COUNT(if(behavior_type = 'fav', behavior_type, NULL)) AS fav,
	COUNT(if(behavior_type = 'buy', behavior_type, NULL)) AS buy
FROM temp_behavior
GROUP BY
	dates,
	hours
ORDER BY
	dates,
	hours;
	
	
	
CREATE TABLE date_hour_behavior
	(
	dates CHAR(10),
	hours	CHAR(2),
	pv INT,
	cart INT,
	fav INT,
	buy INT
	);
	
	
	
INSERT INTO date_hour_behavior
	SELECT
		dates,
		hours,
		COUNT(if(behavior_type = 'pv', behavior_type, NULL)) AS pv,
		COUNT(if(behavior_type = 'cart', behavior_type, NULL)) AS cart,
		COUNT(if(behavior_type = 'fav', behavior_type, NULL)) AS fav,
		COUNT(if(behavior_type = 'buy', behavior_type, NULL)) AS buy
	FROM user_behavior
	GROUP BY
		dates,
		hours
	ORDER BY
		dates,
		hours;
	
	
	
	SELECT * FROM date_hour_behavior;
	
	
	
	
	
	
	
	
	
	
	