USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;

------------------------------------------------------------
-- SECTION 3: TABLE DEFINITIONS
-- Note: Using UPPERCASE, unquoted identifiers (Snowflake default).
------------------------------------------------------------

-- RAW: landed end-of-day prices (append-only)
-- _SRC_FILE  : provenance (S3 key or filename)
-- _INGEST_TS : load audit timestamp
CREATE TABLE IF NOT EXISTS RAW.RAW_EOD_PRICES (
  TRADE_DATE   DATE,
  SYMBOL       STRING,
  OPEN         NUMBER(18,6),
  HIGH         NUMBER(18,6),
  LOW          NUMBER(18,6),
  CLOSE        NUMBER(18,6),
  VOLUME       NUMBER(38,0),
  _SRC_FILE    STRING,
 _INGEST_TS    TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);