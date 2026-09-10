-- ============================================================
-- SA-02: SECURITY DAILY PRICES
-- ============================================================
-- Purpose: Business-ready daily OHLCV with security attributes.
-- Output : SA.VW_SECURITY_DAILY_PRICES
-- ============================================================

USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;
USE SCHEMA SA;

CREATE OR REPLACE VIEW SA.VW_SECURITY_DAILY_PRICES AS
SELECT
    f.SECURITY_ID,
    s.SYMBOL,
    a.SECURITY_NAME,
    a.SECTOR,
    a.INDUSTRY,
    a.SECURITY_TYPE,
    d.CAL_DATE AS TRADE_DATE,
    f.OPEN,
    f.HIGH,
    f.LOW,
    f.CLOSE,
    f.VOLUME
FROM DM_FACT.FACT_DAILY_PRICE f
JOIN DM_DIM.DIM_DATE d
    ON d.DATE_SK = f.DATE_SK
JOIN DM_DIM.DIM_SECURITY s
    ON s.SECURITY_ID = f.SECURITY_ID
LEFT JOIN DM_DIM.DIM_SECURITY_ATTRIBUTES a
    ON a.SYMBOL = s.SYMBOL
WHERE s.IS_ACTIVE = TRUE;

COMMENT ON VIEW SA.VW_SECURITY_DAILY_PRICES IS
'Business-ready daily OHLCV joined with symbol and sector/industry (active universe only).';
