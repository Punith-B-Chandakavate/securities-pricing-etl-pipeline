USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;

------------------------------------------------------------
-- SECTION 3: TABLE DEFINITIONS
-- Note: Using UPPERCASE, unquoted identifiers (Snowflake default).
------------------------------------------------------------

-- CORE: cleaned/pruned version of RAW for downstream joins
CREATE TABLE IF NOT EXISTS CORE.EOD_PRICES (
  TRADE_DATE   DATE,
  SYMBOL       STRING,
  OPEN         NUMBER(18,6),
  HIGH         NUMBER(18,6),
  LOW          NUMBER(18,6),
  CLOSE        NUMBER(18,6),
  VOLUME       NUMBER(38,0),
  LOAD_TS      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);