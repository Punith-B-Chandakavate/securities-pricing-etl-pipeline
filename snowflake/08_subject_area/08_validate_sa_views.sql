-- ============================================================
-- Validate SA Views
-- ============================================================

USE DATABASE SEC_PRICING;

-- List all views in the SA schema
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COMMENT
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'SA'
ORDER BY TABLE_NAME;


-- ============================================================
-- Validate Individual SA Views
-- ============================================================

SELECT *
FROM SEC_PRICING.SA.VW_SECURITY_DAILY_PRICES;

SELECT *
FROM SEC_PRICING.SA.VW_TOP20_EQUITY_BY_VOLUME_DAILY;

SELECT *
FROM SEC_PRICING.SA.VW_WATCHLIST_HISTORY;

SELECT *
FROM SEC_PRICING.SA.VW_SECURITY_LAST_30D_DAILY_RETURN;

SELECT *
FROM SEC_PRICING.SA.VW_SECTOR_LIQUIDITY_LATEST;

SELECT *
FROM SEC_PRICING.SA.VW_ETF_LIQUIDITY_30D_SUMMARY;


-- ============================================================
-- Cleanup
-- ============================================================
-- VW_PRICE_BASE is no longer required by the current SA design.
-- Drop only if it exists.

DROP VIEW IF EXISTS SEC_PRICING.SA.VW_PRICE_BASE;