-- Preserve user_behavior. Rebuild only derived analysis tables.
-- About 100 million rows: allow for sorting, temporary storage and indexes.
USE taobao_user_operations;
SET SESSION time_zone = '+08:00';

SELECT COUNT(*) AS raw_rows,
       SUM(user_id IS NULL OR item_id IS NULL OR category_id IS NULL
           OR behavior_type IS NULL OR timestamps IS NULL) AS rows_with_nulls,
       SUM(behavior_type NOT IN ('pv','fav','cart','buy')) AS invalid_behavior_rows,
       MIN(timestamps) AS minimum_source_timestamp,
       MAX(timestamps) AS maximum_source_timestamp
FROM user_behavior;

CREATE TABLE IF NOT EXISTS user_behavior_clean (
    id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    item_id INT UNSIGNED NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    behavior_type VARCHAR(5) NOT NULL,
    timestamps BIGINT NOT NULL,
    datetimes DATETIME NOT NULL,
    dates DATE NOT NULL,
    times TIME NOT NULL,
    hours TINYINT UNSIGNED NOT NULL,
    KEY idx_clean_user_item (user_id,item_id)
) ENGINE=InnoDB;
TRUNCATE TABLE user_behavior_clean;

-- Equal deduplication keys have the same timestamp, so applying the time
-- window before ROW_NUMBER does not change which in-window row is retained.
-- Keep the first original row, not an arbitrary category/behavior per key.
INSERT INTO user_behavior_clean
    (id,user_id,item_id,category_id,behavior_type,timestamps,datetimes,dates,times,hours)
WITH ranked AS (
    SELECT id,user_id,item_id,category_id,behavior_type,timestamps,
           ROW_NUMBER() OVER (
               PARTITION BY user_id,item_id,timestamps ORDER BY id
           ) AS duplicate_rank
    FROM user_behavior
    WHERE timestamps >= UNIX_TIMESTAMP('2017-11-25 00:00:00')
      AND timestamps <  UNIX_TIMESTAMP('2017-12-04 00:00:00')
)
SELECT id,user_id,item_id,category_id,behavior_type,timestamps,
       FROM_UNIXTIME(timestamps), DATE(FROM_UNIXTIME(timestamps)),
       TIME(FROM_UNIXTIME(timestamps)), HOUR(FROM_UNIXTIME(timestamps))
FROM ranked
WHERE duplicate_rank=1
  AND user_id IS NOT NULL AND item_id IS NOT NULL AND category_id IS NOT NULL
  AND behavior_type IN ('pv','fav','cart','buy');

-- Reusable user-day and user summaries avoid repeating 100-million-row scans.
CREATE TABLE IF NOT EXISTS user_day_summary (
    user_id INT UNSIGNED NOT NULL,
    dates DATE NOT NULL,
    events BIGINT UNSIGNED NOT NULL,
    pv BIGINT UNSIGNED NOT NULL,
    fav BIGINT UNSIGNED NOT NULL,
    cart BIGINT UNSIGNED NOT NULL,
    buy BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id,dates), KEY idx_user_day_date (dates)
) ENGINE=InnoDB;
TRUNCATE TABLE user_day_summary;
INSERT INTO user_day_summary (user_id,dates,events,pv,fav,cart,buy)
SELECT user_id,dates,COUNT(*),SUM(behavior_type='pv'),SUM(behavior_type='fav'),
       SUM(behavior_type='cart'),SUM(behavior_type='buy')
FROM user_behavior_clean GROUP BY user_id,dates;

CREATE TABLE IF NOT EXISTS user_summary (
    user_id INT UNSIGNED NOT NULL PRIMARY KEY,
    events BIGINT UNSIGNED NOT NULL,
    pv BIGINT UNSIGNED NOT NULL,
    fav BIGINT UNSIGNED NOT NULL,
    cart BIGINT UNSIGNED NOT NULL,
    buy BIGINT UNSIGNED NOT NULL,
    active_days TINYINT UNSIGNED NOT NULL,
    last_buy_date DATE NULL
) ENGINE=InnoDB;
TRUNCATE TABLE user_summary;
INSERT INTO user_summary (user_id,events,pv,fav,cart,buy,active_days,last_buy_date)
SELECT user_id,SUM(events),SUM(pv),SUM(fav),SUM(cart),SUM(buy),COUNT(*),
       MAX(CASE WHEN buy>0 THEN dates END)
FROM user_day_summary GROUP BY user_id;

SELECT COUNT(*) AS clean_rows, MIN(datetimes) AS first_event,
       MAX(datetimes) AS last_event FROM user_behavior_clean;
SELECT COUNT(*) AS users, SUM(events) AS events,
       SUM(pv) AS pv,SUM(fav) AS fav,SUM(cart) AS cart,SUM(buy) AS buy
FROM user_summary;
