-- Daily browsing activity. UV is not new-customer acquisition.
USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
CREATE TABLE IF NOT EXISTS pv_uv_puv (
    dates CHAR(10) NOT NULL PRIMARY KEY,
    pv BIGINT UNSIGNED NOT NULL,
    uv BIGINT UNSIGNED NOT NULL,
    puv DECIMAL(18,8) NULL
);
TRUNCATE TABLE pv_uv_puv;
INSERT INTO pv_uv_puv (dates,pv,uv,puv)
SELECT dates,SUM(pv),SUM(pv>0),SUM(pv)*1e0/NULLIF(SUM(pv>0),0)
FROM user_day_summary GROUP BY dates;
SELECT * FROM pv_uv_puv ORDER BY dates;

-- Supplement: daily growth with the previous day as denominator.
WITH previous_day AS (
    SELECT *,LAG(pv) OVER(ORDER BY dates) AS previous_pv,
           LAG(uv) OVER(ORDER BY dates) AS previous_uv,
           LAG(puv) OVER(ORDER BY dates) AS previous_puv
    FROM pv_uv_puv
)
SELECT dates,pv,uv,puv,
       -- Coerce before subtraction: unsigned PV/UV may decrease day to day.
       (pv*1e0-previous_pv)/NULLIF(previous_pv,0) AS pv_growth,
       (uv*1e0-previous_uv)/NULLIF(previous_uv,0) AS uv_growth,
       (puv-previous_puv)/NULLIF(previous_puv,0) AS depth_growth
FROM previous_day ORDER BY dates;
