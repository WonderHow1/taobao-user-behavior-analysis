USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
CREATE TABLE IF NOT EXISTS date_hour_behavior (
    dates CHAR(10) NOT NULL,
    hours CHAR(2) NOT NULL,
    pv BIGINT UNSIGNED NOT NULL,
    cart BIGINT UNSIGNED NOT NULL,
    fav BIGINT UNSIGNED NOT NULL,
    buy BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (dates,hours)
);
TRUNCATE TABLE date_hour_behavior;
INSERT INTO date_hour_behavior (dates,hours,pv,cart,fav,buy)
SELECT dates,LPAD(CAST(hours AS CHAR),2,'0'),SUM(behavior_type='pv'),SUM(behavior_type='cart'),
       SUM(behavior_type='fav'),SUM(behavior_type='buy')
FROM user_behavior_clean GROUP BY dates,hours;
SELECT * FROM date_hour_behavior ORDER BY dates,hours;

-- Sum counts first, then divide. Do not add up daily row-level ratios.
SELECT hours,SUM(pv) AS pv,SUM(fav) AS fav,SUM(cart) AS cart,SUM(buy) AS buy,
       SUM(buy)*1e0/NULLIF(SUM(pv),0) AS purchase_event_pv_ratio,
       (SUM(cart)+SUM(fav))*1e0/NULLIF(SUM(pv),0) AS intent_event_pv_ratio
FROM date_hour_behavior GROUP BY hours ORDER BY hours;
