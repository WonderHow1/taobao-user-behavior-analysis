-- The dataset has no Monetary field: this is RF, not a complete RFM model.
-- The historical table name rfm_model is retained for Tableau compatibility.
USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
CREATE TABLE IF NOT EXISTS rfm_model (
    user_id INT UNSIGNED NOT NULL PRIMARY KEY,
    recency CHAR(10) NOT NULL,
    frequency BIGINT UNSIGNED NOT NULL,
    r_score TINYINT UNSIGNED NOT NULL,
    f_score TINYINT UNSIGNED NOT NULL,
    class VARCHAR(40) NOT NULL
);
TRUNCATE TABLE rfm_model;
INSERT INTO rfm_model (user_id,recency,frequency,r_score,f_score,class)
WITH scores AS (
    SELECT user_id,last_buy_date AS recency,buy AS frequency,
           CASE WHEN last_buy_date='2017-12-03' THEN 5
                WHEN last_buy_date IN ('2017-12-01','2017-12-02') THEN 4
                WHEN last_buy_date IN ('2017-11-29','2017-11-30') THEN 3
                WHEN last_buy_date IN ('2017-11-27','2017-11-28') THEN 2
                ELSE 1 END AS r_score,
           NTILE(5) OVER(ORDER BY buy,user_id) AS f_score
    FROM user_summary WHERE buy>0
), thresholds AS (
    -- Floating-point means retain F average 2.9999970256 for this dataset.
    -- Rounding it to 3.0000 before comparison would change the segmentation.
    SELECT SUM(r_score)*1e0/COUNT(*) AS r_avg,
           SUM(f_score)*1e0/COUNT(*) AS f_avg FROM scores
)
SELECT user_id,recency,frequency,r_score,f_score,
       CASE WHEN r_score>r_avg AND f_score>f_avg THEN '价值用户'
            WHEN r_score>r_avg AND f_score<f_avg THEN '发展用户'
            WHEN r_score<r_avg AND f_score>f_avg THEN '保持用户'
            WHEN r_score<r_avg AND f_score<f_avg THEN '挽留用户'
            ELSE '边界待分类' END
FROM scores CROSS JOIN thresholds;

-- NTILE makes similar-sized groups; equal frequencies can receive different
-- scores. user_id fixes their ordering, not their business value.
SELECT class,COUNT(*) AS users,SUM(frequency) AS purchase_events,
       COUNT(*)*1e0/(SELECT COUNT(*) FROM rfm_model) AS user_share
FROM rfm_model GROUP BY class ORDER BY users DESC;
SELECT f_score,COUNT(*) AS users,MIN(frequency) AS min_purchases,
       MAX(frequency) AS max_purchases
FROM rfm_model GROUP BY f_score ORDER BY f_score;
SELECT frequency,COUNT(*) AS users FROM rfm_model
GROUP BY frequency ORDER BY frequency;
