-- ============================================================
-- Populate Date Dimension
-- ============================================================
--
-- Purpose:
--   - Populate date records available in CORE EOD pricing data
--   - Generate a surrogate date key
--   - Derive common calendar attributes
--   - Support date-based reporting and analytics
--
-- Source:
--   CORE.EOD_PRICES
--
-- Target:
--   DM_DIM.DIM_DATE
--
-- Business Key:
--   DATE_SK
-- ============================================================


USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;


-- ============================================================
-- Merge CORE Trading Dates into Date Dimension
-- ============================================================
-- Purpose:
--   Extract unique trading dates from CORE.EOD_PRICES and
--   generate commonly used calendar attributes for reporting.
--
-- Processing Flow:
--
--   CORE.EOD_PRICES
--          ↓
--   SELECT DISTINCT TRADE_DATE
--          ↓
--   Generate DATE_SK
--          ↓
--   Derive Calendar Attributes
--          ↓
--   MERGE into DM_DIM.DIM_DATE
-- ============================================================

MERGE INTO DM_DIM.DIM_DATE d

USING (

    -- ========================================================
    -- Build Date Dimension Source Dataset
    -- ========================================================
    -- Each row represents one unique trading date from CORE.
    --
    -- The date is transformed into a set of calendar
    -- attributes that can be used directly in reporting.
    -- ========================================================

    SELECT DISTINCT

        -- ----------------------------------------------------
        -- Generate Surrogate Date Key
        -- ----------------------------------------------------
        -- Converts the date into YYYYMMDD numeric format.
        --
        -- Example:
        --   2026-09-07 → 20260907
        --
        -- DATE_SK provides a compact and deterministic key
        -- for identifying a calendar date.
        -- ----------------------------------------------------

        TO_NUMBER(
            TO_CHAR(e.TRADE_DATE, 'YYYYMMDD')
        ) AS DATE_SK,


        -- ----------------------------------------------------
        -- Calendar Date
        -- ----------------------------------------------------
        -- Stores the original trading date.
        -- ----------------------------------------------------

        e.TRADE_DATE AS CAL_DATE,


        -- ----------------------------------------------------
        -- Year
        -- ----------------------------------------------------
        -- Extracts the year from the trading date.
        -- Useful for yearly reporting and filtering.
        -- ----------------------------------------------------

        EXTRACT(YEAR FROM e.TRADE_DATE) AS YEAR_NUM,


        -- ----------------------------------------------------
        -- Quarter
        -- ----------------------------------------------------
        -- Extracts the calendar quarter.
        --
        -- Example:
        --   January-March → Q1
        --   April-June    → Q2
        -- ----------------------------------------------------

        EXTRACT(QUARTER FROM e.TRADE_DATE) AS QUARTER_NUM,


        -- ----------------------------------------------------
        -- Month Number
        -- ----------------------------------------------------
        -- Extracts the numeric month from the trading date.
        -- ----------------------------------------------------

        EXTRACT(MONTH FROM e.TRADE_DATE) AS MONTH_NUM,


        -- ----------------------------------------------------
        -- Month Name
        -- ----------------------------------------------------
        -- Converts the month into a readable name such as
        -- January, February, March, etc.
        -- Useful for dashboard labels and reporting.
        -- ----------------------------------------------------

        MONTHNAME(e.TRADE_DATE) AS MONTH_NAME,


        -- ----------------------------------------------------
        -- Day Number
        -- ----------------------------------------------------
        -- Extracts the day of the month.
        -- ----------------------------------------------------

        EXTRACT(DAY FROM e.TRADE_DATE) AS DAY_NUM,


        -- ----------------------------------------------------
        -- Day Name
        -- ----------------------------------------------------
        -- Converts the day into a readable name such as
        -- Monday, Tuesday, Wednesday, etc.
        -- ----------------------------------------------------

        DAYNAME(e.TRADE_DATE) AS DAY_NAME,


        -- ----------------------------------------------------
        -- Day of Week
        -- ----------------------------------------------------
        -- Extracts the numeric day-of-week value.
        --
        -- Snowflake returns:
        --   0 = Sunday
        --   1 = Monday
        --   ...
        --   6 = Saturday
        --
        -- This attribute is used to identify weekends and
        -- support day-of-week analysis.
        -- ----------------------------------------------------

        EXTRACT(DAYOFWEEK FROM e.TRADE_DATE) AS DAY_OF_WEEK,


        -- ----------------------------------------------------
        -- Week of Year
        -- ----------------------------------------------------
        -- Extracts the week number within the year.
        -- Useful for weekly trend analysis.
        -- ----------------------------------------------------

        EXTRACT(WEEK FROM e.TRADE_DATE) AS WEEK_OF_YEAR,


        -- ----------------------------------------------------
        -- Weekend Flag
        -- ----------------------------------------------------
        -- Identifies whether the date falls on Saturday or
        -- Sunday.
        --
        -- TRUE  → Weekend
        -- FALSE → Weekday
        -- ----------------------------------------------------

        IFF(
            EXTRACT(DAYOFWEEK FROM e.TRADE_DATE) IN (0, 6),
            TRUE,
            FALSE
        ) AS IS_WEEKEND


    FROM CORE.EOD_PRICES e

    -- Sort the generated source dates for easier readability
    -- when inspecting the query results.
    ORDER BY DATE_SK

) s


-- ============================================================
-- Merge Matching Condition
-- ============================================================
-- DATE_SK is used to determine whether the calendar date
-- already exists in the dimension table.
--
-- If DATE_SK exists:
--   → Do nothing
--
-- If DATE_SK does not exist:
--   → Insert the new date
-- ============================================================

ON d.DATE_SK = s.DATE_SK


-- ============================================================
-- Insert New Date
-- ============================================================
-- Insert the generated calendar attributes when the date
-- does not already exist in DIM_DATE.
-- ============================================================

WHEN NOT MATCHED THEN
    INSERT (
        DATE_SK, CAL_DATE, YEAR_NUM, QUARTER_NUM, MONTH_NUM, MONTH_NAME,
        DAY_NUM, DAY_NAME, DAY_OF_WEEK, WEEK_OF_YEAR, IS_WEEKEND
    )
    VALUES (
        s.DATE_SK, s.CAL_DATE, s.YEAR_NUM, s.QUARTER_NUM, s.MONTH_NUM,
        s.MONTH_NAME, s.DAY_NUM, s.DAY_NAME, s.DAY_OF_WEEK, s.WEEK_OF_YEAR, s.IS_WEEKEND
    );


-- ============================================================
-- Validate Date Dimension
-- ============================================================
-- Display the populated date dimension to verify that the
-- expected calendar attributes were generated successfully.
-- ============================================================

SELECT *
FROM DM_DIM.DIM_DATE;