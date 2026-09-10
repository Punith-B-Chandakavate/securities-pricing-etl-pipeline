-- ============================================================
-- SA-05: SECURITY LAST 30 DAYS DAILY RETURN
-- ============================================================
-- Purpose: Last 30 calendar days of equities with prior close
--          and daily percentage return.
-- Output : SA.VW_SECURITY_LAST_30D_DAILY_RETURN
-- ============================================================

USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;
USE SCHEMA SA;

CREATE OR REPLACE VIEW SA.VW_SECURITY_LAST_30D_DAILY_RETURN AS
WITH BOUNDS AS (
    SELECT
        MAX(P.TRADE_DATE) AS MAX_DT,
        DATEADD('day', -29, MAX(P.TRADE_DATE)) AS MIN_DT
    FROM SA.VW_SECURITY_DAILY_PRICES P
),
BASE AS (
    SELECT
        P.TRADE_DATE,
        P.SECURITY_ID,
        P.SYMBOL,
        P.SECURITY_NAME,
        P.SECTOR,
        P.INDUSTRY,
        P.CLOSE,
        P.VOLUME,
        LAG(P.CLOSE) OVER (
            PARTITION BY P.SECURITY_ID
            ORDER BY P.TRADE_DATE
        ) AS PREV_CLOSE
    FROM SA.VW_SECURITY_DAILY_PRICES P
    WHERE P.SECURITY_TYPE = 'Equity'
)
SELECT
    B.*,
    IFF(
        B.PREV_CLOSE IS NULL,
        NULL,
        (B.CLOSE / NULLIF(B.PREV_CLOSE, 0)) - 1
    ) AS DAILY_RETURN
FROM BASE B
JOIN BOUNDS W
    ON B.TRADE_DATE BETWEEN W.MIN_DT AND W.MAX_DT;

COMMENT ON VIEW SA.VW_SECURITY_LAST_30D_DAILY_RETURN IS
'Last 30 calendar days of equities with prior close (computed pre-filter) and daily % change.';
