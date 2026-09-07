------------------------------------------------------------
-- SECTION 3: SCHEMA STRUCTURE
-- Purpose: Create logical containers for ELT layers.
------------------------------------------------------------

-- Layered approach:
-- RAW   : landed as-is from source (immutable; add only)
-- CORE  : cleansed/standardized canonical models
-- DM_DIM: conformed dimensions for analytics
-- DM_FACT: fact tables for analytics
CREATE SCHEMA IF NOT EXISTS SEC_PRICING.RAW;
CREATE SCHEMA IF NOT EXISTS SEC_PRICING.CORE;
CREATE SCHEMA IF NOT EXISTS SEC_PRICING.DM_DIM;
CREATE SCHEMA IF NOT EXISTS SEC_PRICING.DM_FACT;