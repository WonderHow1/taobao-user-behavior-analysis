-- Activity-cohort next-day retention, not first-acquisition retention.
USE taobao_user_operations;
SET SESSION time_zone = '+08:00';
CREATE TABLE IF NOT EXISTS retention_rate (
    dates CHAR(10) NOT NULL PRIMARY KEY,
    retention_rate DECIMAL(18,10) NULL
);
TRUNCATE TABLE retention_rate;
INSERT INTO retention_rate (dates,retention_rate)
SELECT a.dates,
       CASE WHEN a.dates<'2017-12-03'
            THEN COUNT(b.user_id)*1e0/NULLIF(COUNT(*),0)
            ELSE NULL END
FROM user_day_summary a
LEFT JOIN user_day_summary b
  ON a.user_id=b.user_id AND b.dates=DATE_ADD(a.dates,INTERVAL 1 DAY)
GROUP BY a.dates;
SELECT * FROM retention_rate ORDER BY dates;

-- Diagnostic counts. The final day's return count is unobservable, not zero.
SELECT a.dates,COUNT(*) AS active_users,
       CASE WHEN a.dates<'2017-12-03' THEN COUNT(b.user_id) ELSE NULL END AS day1_users
FROM user_day_summary a
LEFT JOIN user_day_summary b
  ON a.user_id=b.user_id AND b.dates=DATE_ADD(a.dates,INTERVAL 1 DAY)
GROUP BY a.dates ORDER BY a.dates;

-- No session identifiers are available. This is a single-event-user share,
-- not a session bounce rate; both numerator and denominator are users.
SELECT SUM(events=1) AS single_event_users,COUNT(*) AS all_users,
       SUM(events=1)*1e0/NULLIF(COUNT(*),0) AS single_event_user_share
FROM user_summary;
