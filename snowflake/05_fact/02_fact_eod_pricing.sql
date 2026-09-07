-- ============================================================
-- Populate Daily Price Fact Table
-- ============================================================
--
-- Purpose:
--   - Build the daily security pricing fact table
--   - Map each security SYMBOL to SECURITY_ID
--   - Map each trading date to DATE_SK
--   - Maintain one row per security per trading date
--   - Update existing pricing records
--   - Insert new pricing records
--   - Capture the fact table load timestamp
--
-- Source Tables:
--   CORE.EOD_PRICES
--   DM_DIM.DIM_SECURITY
--   DM_DIM.DIM_DATE
--
-- Target:
--   DM_FACT.FACT_DAILY_PRICE
--
-- Grain:
--   One row per (SECURITY_ID, DATE_SK)
--
-- Business Key:
--   SECURITY_ID + DATE_SK
-- ============================================================


USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;


-- ============================================================
-- Merge CORE Pricing Data into Daily Price Fact
-- ============================================================
-- Purpose:
--   Build the fact table source dataset by combining:
--
--   CORE.EOD_PRICES
--          ↓
--   DIM_SECURITY → SECURITY_ID
--          ↓
--   DIM_DATE     → DATE_SK
--          ↓
--   FACT_DAILY_PRICE
--
-- The dimension joins replace the natural business values
-- SYMBOL and TRADE_DATE with their corresponding dimension
-- keys used by the fact table.
-- ============================================================

MERGE INTO DM_FACT.FACT_DAILY_PRICE f

USING (

    -- ========================================================
    -- Build Fact Table Source Dataset
    -- ========================================================
    -- This subquery prepares the records that will be loaded
    -- into the fact table.
    --
    -- It:
    --   1. Reads pricing data from CORE.
    --   2. Retrieves SECURITY_ID from DIM_SECURITY.
    --   3. Generates DATE_SK from TRADE_DATE.
    --   4. Validates the date against DIM_DATE.
    --   5. Selects the required pricing measures.
    --
    -- Expected grain:
    --   One row per SECURITY_ID + DATE_SK
    -- ========================================================

    SELECT
        ds.SECURITY_ID,
        TO_NUMBER(TO_CHAR(e.TRADE_DATE, 'YYYYMMDD')) AS DATE_SK,   --  Converts TRADE_DATE into YYYYMMDD format.
        e.TRADE_DATE,
        e.OPEN,
        e.HIGH,
        e.LOW,
        e.CLOSE,
        e.VOLUME
    FROM CORE.EOD_PRICES e

    -- ========================================================
    -- Join Security Dimension
    -- ========================================================

    JOIN DM_DIM.DIM_SECURITY ds
        ON ds.SYMBOL = e.SYMBOL

    -- ========================================================
    -- Join Date Dimension
    -- ========================================================

    JOIN DM_DIM.DIM_DATE dd 
        ON dd.DATE_SK = TO_NUMBER(TO_CHAR(e.TRADE_DATE, 'YYYYMMDD'))
    ) src


-- ============================================================
-- Fact Table Matching Condition
-- ============================================================
-- The fact table grain is:
--
--   SECURITY_ID + DATE_SK
--
-- Therefore, these two columns are used as the matching
-- condition for the MERGE operation.
--
-- If the combination already exists:
--   → Update the pricing information.
--
-- If the combination does not exist:
--   → Insert a new daily price record.
-- ============================================================

ON f.SECURITY_ID = src.SECURITY_ID
AND f.DATE_SK = src.DATE_SK


-- ============================================================
-- Update Existing Fact Record
-- ============================================================
-- When a record already exists for the same security and
-- trading date, update the pricing measures with the latest
-- values from CORE.
-- ============================================================

WHEN MATCHED THEN
    UPDATE SET
        TRADE_DATE = src.TRADE_DATE,
        OPEN       = src.OPEN,
        HIGH       = src.HIGH,
        LOW        = src.LOW,
        CLOSE      = src.CLOSE,
        VOLUME     = src.VOLUME,
        LOAD_TS = CURRENT_TIMESTAMP()     -- Capture the time when the fact record was loaded


-- ============================================================
-- Insert New Fact Record
-- ============================================================
-- When no matching SECURITY_ID + DATE_SK combination exists,
-- insert a new daily pricing record.
-- ============================================================

WHEN NOT MATCHED THEN
    INSERT (
        SECURITY_ID, DATE_SK, TRADE_DATE, OPEN,
        HIGH, LOW, CLOSE, VOLUME, LOAD_TS
    ) VALUES (
        src.SECURITY_ID, src.DATE_SK, src.TRADE_DATE, src.OPEN,
        src.HIGH, src.LOW, src.CLOSE, src.VOLUME, CURRENT_TIMESTAMP()
    );

-- ============================================================
-- Fact Table Sanity Checks
-- ============================================================
-- Validate the number of records loaded into the fact table.
-- ============================================================

SELECT COUNT(*)
FROM SEC_PRICING.DM_FACT.FACT_DAILY_PRICE;

-- ============================================================
-- Inspect Fact Table Data
-- ============================================================
-- Display the loaded fact records for validation.
-- ============================================================

SELECT *
FROM SEC_PRICING.DM_FACT.FACT_DAILY_PRICE;