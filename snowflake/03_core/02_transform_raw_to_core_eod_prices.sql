-- ============================================================
-- Transform and Merge RAW EOD Pricing Data into CORE
-- ============================================================
--
-- Purpose:
--   - Standardize security symbols
--   - Deduplicate RAW EOD pricing records
--   - Keep the latest ingestion per trade date and symbol
--   - Update existing CORE records
--   - Insert new CORE records
--   - Capture the CORE load timestamp
--
-- Source:
--   RAW.RAW_EOD_PRICES
--
-- Target:
--   CORE.EOD_PRICES
--
-- Business Key:
--   TRADE_DATE + SYMBOL
-- ============================================================

USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;

-- ============================================================
-- Validate RAW Data
-- ============================================================
-- Purpose:
--   Quickly inspect the RAW table before performing the
--   transformation and MERGE operation.
-- ============================================================

select * 
from sec_pricing.raw.raw_eod_prices 
limit 5;



MERGE INTO CORE.EOD_PRICES AS EP
USING (

    -- ========================================================
    -- CTE 1: SRC_RAW
    -- ========================================================
    -- Purpose:
    --   Prepare the RAW data before deduplication.
    --
    -- Transformations:
    --   - TRIM() removes leading and trailing spaces
    --     from the security symbol.
    --
    --   - UPPER() converts the security symbol to uppercase
    --     to maintain a consistent format.
    --
    -- Example:
    --   '  aapl  ' → 'AAPL'
    --
    -- The ingestion timestamp and source file are retained
    -- because they are required to determine which duplicate
    -- record is the latest version.
    -- ========================================================

    WITH SRC_RAW AS(
        SELECT
        r.TRADE_DATE,
        UPPER(TRIM(r.SYMBOL)) AS SYMBOL,   -- Remove spaces and standardize symbol to uppercase
        r.OPEN, r.HIGH, r.LOW, R.CLOSE, r.VOLUME,
        r._INGEST_TS,                  -- stronger dedup signal (most recent load wins)
        r._SRC_FILE                    -- deterministic tie-breaker if ingest_ts ties
        FROM RAW.RAW_EOD_PRICES r
    ),
    
    -- ========================================================
    -- CTE 2: RANKED
    -- ========================================================
    -- Purpose:
    --   Identify duplicate pricing records and select the
    --   latest record for each TRADE_DATE + SYMBOL combination.
    --
    -- Business Key:
    --   TRADE_DATE + SYMBOL
    --
    -- ROW_NUMBER() assigns a ranking to records within each
    -- trade date and security symbol.
    --
    -- ORDER BY:
    --   1. _INGEST_TS DESC → latest ingestion gets rank 1
    --   2. _SRC_FILE DESC  → tie-breaker when timestamps match
    --
    -- After ranking, only rn = 1 is selected.
    -- ========================================================
    
    RANKED AS (
        SELECT
        TRADE_DATE, SYMBOL, OPEN, HIGH, LOW, CLOSE, VOLUME, _INGEST_TS, _SRC_FILE,
        ROW_NUMBER() OVER(
            PARTITION BY TRADE_DATE, SYMBOL
            ORDER BY _INGEST_TS DESC, _SRC_FILE DESC
        ) AS rn
        FROM SRC_RAW
    )
    
    -- ========================================================
    -- Select the latest record for each business key
    -- ========================================================
    -- rn = 1 represents the latest available record for each
    -- TRADE_DATE + SYMBOL combination.
    -- ========================================================
    
    SELECT 
        TRADE_DATE, SYMBOL, OPEN, HIGH, LOW, CLOSE, VOLUME
    FROM RANKED
    WHERE rn=1
) AS LP

-- ============================================================
-- MERGE Matching Condition
-- ============================================================
-- Match SOURCE and TARGET using the business key:
--
--   TRADE_DATE + SYMBOL
--
-- If a matching record already exists in CORE, it is updated.
-- If no matching record exists, a new record is inserted.
-- ============================================================

ON EP.SYMBOL = LP.SYMBOL
AND EP.TRADE_DATE = LP.TRADE_DATE

-- ============================================================
-- Update Existing Records
-- ============================================================
-- If the business key already exists, update the pricing
-- values with the latest RAW data.
-- ============================================================

WHEN MATCHED THEN 
    UPDATE SET
        EP.OPEN = LP.OPEN,
        EP.HIGH = LP.HIGH,
        EP.LOW = LP.LOW,
        EP.CLOSE = LP.CLOSE,
        EP.VOLUME = LP.VOLUME,
        EP.LOAD_TS = CURRENT_TIMESTAMP()

-- ============================================================
-- Insert New Records
-- ============================================================
-- If the business key does not exist in CORE, insert the
-- transformed pricing record as a new record.
-- ============================================================

WHEN NOT MATCHED THEN
    INSERT (
        TRADE_DATE, SYMBOL, OPEN, HIGH, LOW, CLOSE, VOLUME, LOAD_TS
    ) VALUES (
        LP.TRADE_DATE, LP.SYMBOL, LP.OPEN, LP.HIGH, LP.LOW, LP.CLOSE, LP.VOLUME, CURRENT_TIMESTAMP()
    );
