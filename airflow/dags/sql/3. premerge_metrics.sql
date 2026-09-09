-- ============================================================
-- S03: COMPUTE PRE-MERGE METRICS
-- ============================================================
--
-- Purpose:
--   Calculate audit and data-quality metrics before merging
--   RAW EOD pricing data into the CORE layer.
--
-- Metrics:
--   - Total RAW records for the trading date
--   - Rejected records based on data-quality rules
--   - Valid unique security/date keys
--   - Estimated CORE inserts
--   - Estimated CORE updates
--
-- Current rejection rule:
--   VOLUME < 0
--
-- Source:
--   RAW.RAW_EOD_PRICES
--
-- Target:
--   CORE.EOD_PRICES
--
-- Airflow:
--   Trading date is received through XCom.
--
-- ============================================================


-- Set Snowflake execution context
USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;


-- ============================================================
-- 1. Resolve Trading Date
-- ============================================================

WITH td AS (
    -- Pull trading date dynamically from Airflow XCom context
    SELECT TO_DATE('{{ ti.xcom_pull(task_ids=params.trading_ds_task_id, key="trading_date") }}') AS d
),

-- ============================================================
-- 2. Count All RAW Records
-- ============================================================

raw_cnt AS (
    SELECT
        COUNT(*) AS c
    FROM RAW.RAW_EOD_PRICES
    WHERE TRADE_DATE = (SELECT d FROM td)
),

-- ============================================================
-- 3. Identify Rejected Records
-- ============================================================
--
-- Current data-quality rule:
--   Negative volume is considered invalid.
--
-- These records will be handled by the CORE merge process
-- and stored in the reject table instead of CORE.
-- ============================================================

reject_cnt AS (
    SELECT
        COUNT(*) AS c
    FROM RAW.RAW_EOD_PRICES
    WHERE TRADE_DATE = (SELECT d FROM td)
      AND VOLUME < 0
),

-- ============================================================
-- 4. Identify Valid RAW Keys
-- ============================================================
--
-- Exclude rejected records.
--
-- Business key:
--   TRADE_DATE + SYMBOL
--
-- Symbol is normalized using TRIM and UPPER.
-- ============================================================

valid_keys AS (
    SELECT DISTINCT
        UPPER(TRIM(SYMBOL)) AS SYMBOL,
        TRADE_DATE
    FROM RAW.RAW_EOD_PRICES
    WHERE TRADE_DATE = (SELECT d FROM td)
      AND VOLUME >= 0
),

-- ============================================================
-- 5. Count Existing CORE Keys
-- ============================================================
--
-- Existing valid keys represent potential CORE updates.
-- ============================================================

core_existing AS (
    SELECT
        COUNT(*) AS c
    FROM valid_keys r
    JOIN CORE.EOD_PRICES c
        ON UPPER(TRIM(c.SYMBOL)) = r.SYMBOL
       AND c.TRADE_DATE = r.TRADE_DATE
),

-- ============================================================
-- 6. Count Total Valid Keys
-- ===========================================================

total_valid_keys AS (
    SELECT
        COUNT(*) AS c
    FROM valid_keys
)

-- ============================================================
-- 7. Return Pre-Merge Metrics
-- ============================================================

SELECT
    r.c AS raw_cnt,
    rej.c AS reject_cnt,
    t.c AS valid_key_cnt,
    (t.c - e.c) AS est_inserts,
    e.c AS est_updates
FROM raw_cnt r
CROSS JOIN reject_cnt rej
CROSS JOIN total_valid_keys t
CROSS JOIN core_existing e;