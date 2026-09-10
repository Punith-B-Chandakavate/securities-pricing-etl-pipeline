-- ============================================================
-- SA-03: TOP 20 EQUITIES BY DAILY VOLUME
-- ============================================================
-- Purpose: Identify the top 20 equities by daily volume.
-- Output : SA.VW_TOP20_EQUITY_BY_VOLUME_DAILY
-- ============================================================

USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;
USE SCHEMA SA;

CREATE OR REPLACE VIEW SA.VW_TOP20_EQUITY_BY_VOLUME_DAILY AS
SELECT
    p.TRADE_DATE,
    p.SYMBOL,
    p.SECURITY_NAME,
    p.SECTOR,
    p.INDUSTRY,
    p.VOLUME,
    p.CLOSE,
    (p.CLOSE * p.VOLUME) AS TRADED_VALUE
FROM (
    SELECT
        p.*,
        ROW_NUMBER() OVER (
            PARTITION BY p.TRADE_DATE
            ORDER BY p.VOLUME DESC
        ) AS RN
    FROM SA.VW_SECURITY_DAILY_PRICES p
    WHERE p.SECURITY_TYPE = 'Equity'
) p
WHERE p.RN <= 20;

COMMENT ON VIEW SA.VW_TOP20_EQUITY_BY_VOLUME_DAILY IS
'Daily Top-20 most actively traded equities by volume with traded value (liquidity screen).';
