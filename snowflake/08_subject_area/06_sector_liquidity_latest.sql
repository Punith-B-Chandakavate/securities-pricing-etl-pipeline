-- ============================================================
-- SA-06: LATEST SECTOR LIQUIDITY
-- ============================================================
-- Purpose: Latest trading-day sector liquidity, traded value,
--          symbol count and percentage contribution.
-- Output : SA.VW_SECTOR_LIQUIDITY_LATEST
-- ============================================================

USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;
USE SCHEMA SA;

CREATE OR REPLACE VIEW SA.VW_SECTOR_LIQUIDITY_LATEST AS
WITH LAST_DAY AS (
    SELECT MAX(TRADE_DATE) AS DT
    FROM SA.VW_SECURITY_DAILY_PRICES
),
SECTOR_LIQ AS (
    SELECT
        P.SECTOR,
        D.DT AS TRADE_DATE,
        COUNT(*) AS SYMBOLS_COUNT,
        SUM(P.CLOSE * P.VOLUME) AS TRADED_VALUE
    FROM SA.VW_SECURITY_DAILY_PRICES P
    JOIN LAST_DAY D
        ON P.TRADE_DATE = D.DT
    WHERE P.SECURITY_TYPE = 'Equity'
    GROUP BY P.SECTOR, D.DT
),
TOTAL_LIQ AS (
    SELECT
        TRADE_DATE,
        SUM(TRADED_VALUE) AS TOTAL_TRADED_VALUE
    FROM SECTOR_LIQ
    GROUP BY TRADE_DATE
)
SELECT
    S.TRADE_DATE,
    S.SECTOR,
    S.SYMBOLS_COUNT,
    S.TRADED_VALUE,
    (S.TRADED_VALUE / NULLIF(T.TOTAL_TRADED_VALUE, 0)) AS PCT_CONTRIBUTION
FROM SECTOR_LIQ S
JOIN TOTAL_LIQ T
    ON S.TRADE_DATE = T.TRADE_DATE
ORDER BY S.TRADED_VALUE DESC;

COMMENT ON VIEW SA.VW_SECTOR_LIQUIDITY_LATEST IS
'Latest trading-day sector liquidity snapshot: traded value, number of names, and % contribution of each sector to market liquidity.';
