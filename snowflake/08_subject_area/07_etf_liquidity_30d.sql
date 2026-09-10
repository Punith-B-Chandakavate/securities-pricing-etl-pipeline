-- ============================================================
-- SA-07: ETF 30-DAY LIQUIDITY SUMMARY
-- ============================================================
-- Purpose: ETF 30-day average volume/traded value with latest
--          metrics and 30-day liquidity ranking.
-- Output : SA.VW_ETF_LIQUIDITY_30D_SUMMARY
-- ============================================================

USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;
USE SCHEMA SA;

CREATE OR REPLACE VIEW SA.VW_ETF_LIQUIDITY_30D_SUMMARY AS
WITH BASE AS (
    SELECT
        P.TRADE_DATE,
        P.SECURITY_ID,
        P.SYMBOL,
        P.SECURITY_NAME,
        P.CLOSE,
        P.VOLUME,
        (P.CLOSE * P.VOLUME) AS TRADED_VALUE
    FROM SA.VW_SECURITY_DAILY_PRICES P
    WHERE P.SECURITY_TYPE = 'ETF'
),
AGG AS (
    SELECT
        SECURITY_ID,
        SYMBOL,
        SECURITY_NAME,
        AVG(VOLUME) OVER (
            PARTITION BY SECURITY_ID
            ORDER BY TRADE_DATE
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS AVG_VOLUME_30D,
        AVG(TRADED_VALUE) OVER (
            PARTITION BY SECURITY_ID
            ORDER BY TRADE_DATE
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS AVG_TRADED_VALUE_30D,
        TRADE_DATE,
        CLOSE,
        VOLUME,
        TRADED_VALUE
    FROM BASE
),
LATEST AS (
    SELECT *
    FROM (
        SELECT
            A.*,
            ROW_NUMBER() OVER (
                PARTITION BY SECURITY_ID
                ORDER BY TRADE_DATE DESC
            ) AS RN
        FROM AGG A
    )
    WHERE RN = 1
)
SELECT
    TRADE_DATE AS LAST_TRADE_DATE,
    SECURITY_ID,
    SYMBOL,
    SECURITY_NAME,
    AVG_VOLUME_30D,
    AVG_TRADED_VALUE_30D,
    CLOSE AS LAST_CLOSE,
    VOLUME AS LAST_VOLUME,
    TRADED_VALUE AS LAST_TRADED_VALUE,
    ROW_NUMBER() OVER (
        ORDER BY AVG_TRADED_VALUE_30D DESC NULLS LAST
    ) AS LIQUIDITY_RANK_30D
FROM LATEST
ORDER BY LIQUIDITY_RANK_30D;

COMMENT ON VIEW SA.VW_ETF_LIQUIDITY_30D_SUMMARY IS
'ETF liquidity screener: 30-day average volume & traded value per ETF, with latest-day metrics and a 30D liquidity rank.';
