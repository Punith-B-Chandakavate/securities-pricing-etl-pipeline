USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;

------------------------------------------------------------
-- SECTION 3: TABLE DEFINITIONS
-- Note: Using UPPERCASE, unquoted identifiers (Snowflake default).
------------------------------------------------------------

-- DM_DIM: conformed dimensions
-- Surrogate key via IDENTITY; SYMBOL kept unique to avoid dup members.
CREATE TABLE IF NOT EXISTS DM_DIM.DIM_SECURITY (
  SECURITY_ID  NUMBER IDENTITY START 1 INCREMENT 1,
  SYMBOL       STRING UNIQUE,
  IS_ACTIVE    BOOLEAN DEFAULT TRUE,
  LOAD_TS      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  CONSTRAINT PK_DIM_SECURITY PRIMARY KEY (SECURITY_ID)
);


-- date dimension
CREATE TABLE IF NOT EXISTS DM_DIM.DIM_DATE (
  DATE_SK       NUMBER(8,0),          -- yyyymmdd integer surrogate
  CAL_DATE      DATE UNIQUE,
  YEAR_NUM      NUMBER(4,0),
  QUARTER_NUM   NUMBER(1,0),
  MONTH_NUM     NUMBER(2,0),
  MONTH_NAME    VARCHAR(20),
  DAY_NUM       NUMBER(2,0),
  DAY_NAME      VARCHAR(20),
  DAY_OF_WEEK   NUMBER(1,0),
  WEEK_OF_YEAR  NUMBER(2,0),
  IS_WEEKEND    BOOLEAN,
  CONSTRAINT PK_DIM_DATE PRIMARY KEY (DATE_SK)
);