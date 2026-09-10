-- ============================================================
-- SA-01: CREATE SECURITY ATTRIBUTES TABLE
-- ============================================================
-- Purpose: Store business/classification attributes for securities
-- Target : DM_DIM.DIM_SECURITY_ATTRIBUTES
-- ============================================================

USE WAREHOUSE WH_INGEST;
USE DATABASE SEC_PRICING;

CREATE SCHEMA IF NOT EXISTS SA;
USE SCHEMA SA;

CREATE OR REPLACE TABLE DM_DIM.DIM_SECURITY_ATTRIBUTES (
    SYMBOL          VARCHAR(50)  NOT NULL,
    SECURITY_NAME   VARCHAR(255),
    SECURITY_TYPE   VARCHAR(50),
    SECTOR          VARCHAR(100),
    INDUSTRY        VARCHAR(150),
    WEBSITE_URL     VARCHAR(255)
);
