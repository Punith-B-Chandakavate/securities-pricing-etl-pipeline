-- ============================================================
-- Populate Security Dimension
-- ============================================================
--
-- Purpose:
--   - Extract unique securities from CORE EOD pricing data
--   - Generate a deterministic SECURITY_ID
--   - Populate the DIM_SECURITY dimension table
--   - Maintain a unique security reference for downstream
--     fact tables and analytics
--
-- Source:
--   CORE.EOD_PRICES
--
-- Target:
--   DM_DIM.DIM_SECURITY
--
-- Business Key:
--   SYMBOL
-- ============================================================


USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;


-- ============================================================
-- Validate Source and Target Tables
-- ============================================================
-- Purpose:
--   Quickly inspect the CORE pricing data and existing
--   security dimension before performing the load.
-- ============================================================

SELECT *
FROM CORE.EOD_PRICES
LIMIT 5;

SELECT *
FROM DM_DIM.DIM_SECURITY
LIMIT 5;


-- ============================================================
-- Reset Security Dimension
-- ============================================================
-- Purpose:
--   Remove all existing records before rebuilding the
--   security dimension from the current CORE data.
--
-- Note:
--   TRUNCATE removes all records but keeps the table structure.
-- ============================================================

TRUNCATE TABLE DM_DIM.DIM_SECURITY;


-- ============================================================
-- Merge Unique Securities into Dimension Table
-- ============================================================
-- Purpose:
--   Build the security dimension using distinct symbols
--   available in the CORE EOD pricing table.
--
-- Processing Flow:
--
--   CORE.EOD_PRICES
--          ↓
--   SELECT DISTINCT SYMBOL
--          ↓
--   Generate SECURITY_ID
--          ↓
--   MERGE into DIM_SECURITY
--
-- Since the dimension is truncated before this operation,
-- all current securities will be inserted into the dimension.
-- ============================================================

MERGE INTO DM_DIM.DIM_SECURITY AS DS

USING (

    -- ========================================================
    -- Generate a sequential ID for each security
    -- ========================================================
    -- ROW_NUMBER() generates a unique sequential number
    -- based on the alphabetical order of SYMBOL.
    --
    -- Example:
    --
    --   AAPL → 1
    --   AMZN → 2
    --   GOOGL → 3
    --   MSFT → 4
    --
    -- The generated value is used as SECURITY_ID.
    -- ========================================================

    SELECT
        SYMBOL,
        ROW_NUMBER() OVER (ORDER BY SYMBOL) AS EXPECTED_ID

    FROM (

        -- ====================================================
        -- Extract unique securities
        -- ====================================================
        -- DISTINCT removes duplicate SYMBOL values because
        -- the CORE table contains multiple EOD price records
        -- for the same security across different trade dates.
        --
        -- Example:
        --
        --   AAPL | 2026-09-01
        --   AAPL | 2026-09-02
        --   AAPL | 2026-09-03
        --
        -- becomes:
        --
        --   AAPL
        -- ====================================================

        SELECT DISTINCT SYMBOL
        FROM CORE.EOD_PRICES

    )

) AS EP


-- ============================================================
-- Match Source and Target
-- ============================================================
-- SYMBOL is the business key of the security dimension.
--
-- If the symbol already exists in the dimension, no new
-- record is inserted.
-- ============================================================

ON EP.SYMBOL = DS.SYMBOL


-- ============================================================
-- Insert New Securities
-- ============================================================
-- When a SYMBOL does not exist in DIM_SECURITY, insert a
-- new security record with the generated SECURITY_ID.
-- ============================================================

WHEN NOT MATCHED THEN
    INSERT (
        SECURITY_ID, SYMBOL
    ) VALUES (
        EP.EXPECTED_ID, EP.SYMBOL
    );