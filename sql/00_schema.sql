-- MySQL 8.0+. Execute 00 through 11 in filename order.
-- This file creates an empty raw table; it does not import or delete data.
CREATE DATABASE IF NOT EXISTS taobao_user_operations
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE taobao_user_operations;
SET SESSION time_zone = '+08:00';

-- id records source CSV order, which is the tie-break for deduplication.
-- For an existing table, confirm that its id has this meaning before 01.
CREATE TABLE IF NOT EXISTS user_behavior (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NULL,
    item_id INT UNSIGNED NULL,
    category_id INT UNSIGNED NULL,
    behavior_type VARCHAR(5) NULL,
    timestamps BIGINT NULL
) ENGINE=InnoDB;

-- Import the five-column, headerless source CSV once, in source order.
-- The relative path is an example. Enable LOCAL in your client only if needed;
-- no server-wide settings or credentials are embedded in these scripts.
-- Do not import the same source twice into the raw table.
-- LOAD DATA LOCAL INFILE 'data/raw/UserBehavior.csv'
-- INTO TABLE user_behavior
-- FIELDS TERMINATED BY ','
-- LINES TERMINATED BY '\n'
-- (user_id, item_id, category_id, behavior_type, timestamps);

SELECT COUNT(*) AS raw_rows FROM user_behavior;
