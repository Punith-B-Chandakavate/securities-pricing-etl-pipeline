-- ============================================================
-- SA-04: WATCHLIST HISTORY
-- ============================================================
-- Purpose: Historical pricing, volume and traded value for
--          the defined equity watchlist.
-- Output : SA.VW_WATCHLIST_HISTORY
-- ============================================================

USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;
USE SCHEMA SA;

CREATE OR REPLACE VIEW SA.VW_WATCHLIST_HISTORY AS
WITH WATCHLIST (SYMBOL, RANK_ORDER, NOTE) AS (
    SELECT COLUMN1, COLUMN2, COLUMN3
    FROM VALUES
        ('AAPL',  1, 'Mega-cap tech'),
        ('MSFT',  2, 'Cloud + AI'),
        ('NVDA',  3, 'Semis momentum'),
        ('AMZN',  4, 'Retail + cloud'),
        ('GOOGL', 5, 'Search + AI'),
        ('META',  6, 'Ads + VR'),
        ('TSLA',  7, 'Auto + energy'),
        ('JPM',   8, 'Bank bellwether'),
        ('XOM',   9, 'Energy major'),
        ('UNH',  10, 'Healthcare payer')
)
SELECT
    w.RANK_ORDER,
    p.TRADE_DATE,
    p.SYMBOL,
    p.SECURITY_NAME,
    p.SECTOR,
    p.INDUSTRY,
    p.OPEN,
    p.HIGH,
    p.LOW,
    p.CLOSE,
    p.VOLUME,
    (p.CLOSE * p.VOLUME) AS TRADED_VALUE,
    w.NOTE
FROM WATCHLIST w
JOIN SA.VW_SECURITY_DAILY_PRICES p
    ON p.SYMBOL = w.SYMBOL
WHERE p.SECURITY_TYPE = 'Equity';

COMMENT ON VIEW SA.VW_WATCHLIST_HISTORY IS
'Time-series view of key watchlist equities including price, volume, and traded value — supports trend monitoring and focus dashboards.';
