------------------------------------------------------------
-- SECTION 1: WAREHOUSE SETUP
-- Purpose: Lightweight, cost-friendly compute for ingestion/ELT.
------------------------------------------------------------


-- Auto-suspend after 60s to minimize cost; auto-resume on demand.
-- INITIALLY_SUSPENDED prevents the cluster from starting on create.
CREATE WAREHOUSE IF NOT EXISTS WH_INGEST
  WAREHOUSE_SIZE                = 'XSMALL'          -- keep tiny; scale later if needed
  AUTO_SUSPEND                  = 60                -- seconds of inactivity before suspend
  AUTO_RESUME                   = TRUE              -- wake up on first query
  INITIALLY_SUSPENDED           = TRUE              -- do not start at create time
  STATEMENT_TIMEOUT_IN_SECONDS  = 3600              -- guardrail for runaway queries
  COMMENT                       = 'ETL ingest warehouse';
