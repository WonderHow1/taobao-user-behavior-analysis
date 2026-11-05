INSERT INTO funnel

WITH user_flags AS (
    -- 每位用户是否发生过相应行为
    SELECT
        user_id,
        MAX(behavior_type = 'pv') AS has_pv,
        MAX(behavior_type IN ('fav', 'cart')) AS has_intent,
        MAX(behavior_type = 'buy') AS has_buy
    FROM user_behavior
    GROUP BY user_id
),

funnel_counts AS (
    -- 后一层必须同时满足前面各层的条件
    SELECT
        COUNT(IF(has_pv = 1, user_id, NULL)) AS pv_users,

        COUNT(IF(
            has_pv = 1 AND has_intent = 1,
            user_id, NULL
        )) AS intent_users,

        COUNT(IF(
            has_pv = 1 AND has_intent = 1 AND has_buy = 1,
            user_id, NULL
        )) AS buy_users
    FROM user_flags
),

funnel_steps AS (
    SELECT
        1 AS step_no,
        '浏览' AS stage,
        pv_users AS users,
        pv_users AS previous_users,
        pv_users AS first_users
    FROM funnel_counts

    UNION ALL

    SELECT
        2, '收藏或加购',
        intent_users, pv_users, pv_users
    FROM funnel_counts

    UNION ALL

    SELECT
        3, '购买',
        buy_users, intent_users, pv_users
    FROM funnel_counts
)

SELECT
    step_no AS `步骤`,
    stage AS `阶段`,
    users AS `用户数`,
    ROUND(
        users / NULLIF(previous_users, 0), 2
    ) AS `上一步转化率(%)`,
    ROUND(
        users / NULLIF(first_users, 0), 2
    ) AS `总体转化率(%)`
FROM funnel_steps
ORDER BY step_no;



CREATE TABLE funnel
	(
	step_id INT,
	step VARCHAR(40),
	user_unm INT,
	step_conversion_rate DECIMAL(5,2),
	overall_conversion_rate DECIMAL(5,2)
	);
	
	
