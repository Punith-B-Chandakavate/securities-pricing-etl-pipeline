USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;

------------------------------------------------------------
-- SECTION 3: TABLE DEFINITIONS
-- Note: Using UPPERCASE, unquoted identifiers (Snowflake default).
------------------------------------------------------------

-- DM_FACT: grain = (SECURITY_ID, DATE_SK)
CREATE TABLE IF NOT EXISTS DM_FACT.FACT_DAILY_PRICE (
  SECURITY_ID  NUMBER,                -- FK → DM_DIM.DIM_SECURITY.SECURITY_ID
  DATE_SK      NUMBER(8,0),           -- FK → DM_DIM.DIM_DATE.DATE_SK
  TRADE_DATE   DATE,                  -- denormalized copy
  OPEN         NUMBER(18,6),
  HIGH         NUMBER(18,6),
  LOW          NUMBER(18,6),
  CLOSE        NUMBER(18,6),
  VOLUME       NUMBER(38,0),
  LOAD_TS      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  CONSTRAINT PK_FACT_DAILY PRIMARY KEY (SECURITY_ID, DATE_SK)
);