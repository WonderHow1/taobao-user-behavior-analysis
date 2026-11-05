USE taobao_user_operations;
DESC user_behavior;
SELECT * FROM user_behavior LIMIT 10;

-- 创建进度表
CREATE TABLE IF NOT EXISTS datetime_job_progress (
    job VARCHAR(50) PRIMARY KEY,
    last_id BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

INSERT IGNORE INTO datetime_job_progress
VALUES ('user_behavior', 0);

DELIMITER $$

CREATE PROCEDURE update_datetimes_all()
BEGIN
    DECLARE v_last BIGINT DEFAULT 0;
    DECLARE v_max BIGINT DEFAULT 0;
    DECLARE v_end BIGINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT COALESCE(MAX(id), 0) INTO v_max
    FROM user_behavior;

    batch_loop: LOOP

        START TRANSACTION;

        SELECT last_id INTO v_last
        FROM datetime_job_progress
        WHERE job = 'user_behavior'
        FOR UPDATE;

        IF v_last >= v_max THEN
            COMMIT;
            LEAVE batch_loop;
        END IF;

        SET v_end = LEAST(v_last + 1000, v_max);

        UPDATE user_behavior
        SET datetimes = FROM_UNIXTIME(timestamps)
        WHERE id > v_last
          AND id <= v_end
          AND timestamps BETWEEN 1 AND 2147483647
          AND datetimes IS NULL;

        UPDATE datetime_job_progress
        SET last_id = v_end
        WHERE job = 'user_behavior';

        COMMIT;

    END LOOP;

    SELECT last_id AS completed_id,
           v_max AS max_id
    FROM datetime_job_progress
    WHERE job = 'user_behavior';

END$$

DELIMITER ;


CALL update_datetime_batch(1001, 1);

CALL update_datetime_batch(2001, 10);

CALL update_datetimes_all();


SELECT
    trx_mysql_thread_id,
    trx_state,
    trx_rows_modified,
    trx_started
FROM information_schema.innodb_trx;


---


CREATE TABLE IF NOT EXISTS string_update_progress (
    task_name VARCHAR(50) PRIMARY KEY,
    last_id BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

INSERT IGNORE INTO string_update_progress
VALUES ('user_behavior', 0);

DELIMITER $$

CREATE PROCEDURE update_all_strings(
    IN p_max_batches INT
)
BEGIN
    DECLARE v_last BIGINT DEFAULT 0;
    DECLARE v_end BIGINT DEFAULT 0;
    DECLARE v_max BIGINT DEFAULT 0;
    DECLARE v_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 统一使用北京时间
    SET SESSION time_zone = '+08:00';

    SELECT COALESCE(MAX(id), 0)
    INTO v_max
    FROM user_behavior;

    batch_loop: LOOP

        IF v_count >= p_max_batches THEN
            LEAVE batch_loop;
        END IF;

        START TRANSACTION;

        SELECT last_id INTO v_last
        FROM string_update_progress
        WHERE task_name = 'user_behavior'
        FOR UPDATE;

        IF v_last >= v_max THEN
            COMMIT;
            LEAVE batch_loop;
        END IF;

        SET v_end = LEAST(v_last + 1000, v_max);

        UPDATE user_behavior
        SET
            datetimes = COALESCE(
                datetimes,
                FROM_UNIXTIME(timestamps)
            ),
            dates = SUBSTRING(datetimes, 1, 10),
            times = SUBSTRING(datetimes, 12, 8),
            hours = SUBSTRING(datetimes, 12, 2)
        WHERE id > v_last
          AND id <= v_end
          AND timestamps BETWEEN 1 AND 2147483647
          AND (
              datetimes IS NULL
              OR dates IS NULL
              OR times IS NULL
              OR hours IS NULL
          );

        UPDATE string_update_progress
        SET last_id = v_end
        WHERE task_name = 'user_behavior';

        COMMIT;

        SET v_count = v_count + 1;

    END LOOP;

    SELECT
        last_id AS completed_id,
        v_max AS max_id,
        v_count AS batches_this_run
    FROM string_update_progress
    WHERE task_name = 'user_behavior';

END$$

DELIMITER ;
CALL update_all_strings(1);

CALL update_all_strings(200000);
CALL update_all_strings(1000000);

