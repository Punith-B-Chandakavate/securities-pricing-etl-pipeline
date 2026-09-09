# 🔄 Snowflake CORE EOD Merge

![Apache Airflow](https://img.shields.io/badge/Apache%20Airflow-Workflow%20Orchestration-017CEE?logo=apacheairflow&logoColor=white)
![Snowflake](https://img.shields.io/badge/Snowflake-CORE%20Merge-29B5E8?logo=snowflake&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-MERGE-CC2927?logo=microsoftsqlserver&logoColor=white)
![Data Quality](https://img.shields.io/badge/Data%20Quality-Reject%20Handling-4CAF50)

> **Incremental EOD processing: RAW → CORE**

This document explains how End-of-Day (EOD) security pricing data is validated, measured, rejected when required, and upserted from the Snowflake **RAW** layer into the **CORE** layer.

The process is designed to be **incremental and idempotent for a trading date**, while providing visibility into inserts, updates, and rejected records.

---

## 📑 Table of Contents

- 🎯 Overview
- 🏗️ Processing Architecture
- 📂 SQL Components
- 1️⃣ Pre-Merge Metrics
- 2️⃣ Reject Table
- 3️⃣ CORE Merge
- 🔄 Airflow Workflow
- 🛡️ Data Quality and Reject Handling
- 🔁 Idempotency
- 📊 Processing Metrics
- 📁 Related Source Files
- 🎤 Interview Questions
- ✅ Validation Checklist

---

# 🎯 Overview

The CORE merge is the transformation step that moves validated EOD pricing records from:

```text
RAW
 │
 ▼
S03 Pre-Merge Metrics
 │
 │  COUNT invalid records
 │
 ▼
S04 CORE Merge
 │
 ├── VOLUME < 0 ──→ REJECT TABLE
 │
 └── VOLUME >= 0 ─→ CORE
````

The process performs three main activities:

1. 📊 Calculate pre-merge metrics.
2. 🚫 Capture records with negative volume.
3. 🔄 Upsert valid EOD pricing records into `CORE.EOD_PRICES`.

The trading date is received from the Airflow task through **XCom** and passed into the Snowflake SQL using Airflow template parameters.

---

# 🏗️ Processing Architecture

```text
                    RAW.RAW_EOD_PRICES
                           │
                           ▼
                  PRE-MERGE METRICS
                           │
                           ▼
                     CORE MERGE
                           │
                ┌──────────┴──────────┐
                │                     │
          VOLUME < 0             VOLUME >= 0
                │                     │
                ▼                     ▼
    CORE.EOD_PRICES_REJECT     CORE.EOD_PRICES
                │                     │
                │                     ▼
                │               DIMENSIONS
                │                     │
                │                     ▼
                │                   FACT
                │
                ▼
          Audit / Analysis
```

---

# 📂 SQL Components

The CORE processing uses the following SQL files:

| # | SQL File                    | Purpose                                                               |
| - | --------------------------- | --------------------------------------------------------------------- |
| 1 | `3. premerge_metrics.sql`   | Calculates RAW, reject, estimated insert, and estimated update counts |
| 2 | `reject_table_creation.sql` | Creates the reject table for invalid EOD records                      |
| 3 | `4. merge_core.sql`         | Captures rejected rows and merges valid rows into CORE                |

---

# 1️⃣ Pre-Merge Metrics

## 📊 Purpose

Before modifying the CORE table, the pipeline calculates metrics for the current trading date.

The query determines:

* Total RAW records
* Negative-volume records
* Valid unique security/date keys
* Existing CORE records
* Estimated inserts
* Estimated updates

The trading date is retrieved from the Airflow XCom value:

```sql
TO_DATE(
    '{{ ti.xcom_pull(
        task_ids=params.trading_ds_task_id,
        key="trading_date"
    ) }}'
)
```

---

## 🔢 Metrics Calculation

The SQL uses several CTEs:

```text
Trading Date
     │
     ▼
RAW Count
     │
     ├──────────────► Reject Count
     │
     ▼
Valid Keys
     │
     ├──────────────► Existing CORE Keys
     │
     ▼
Total Valid Keys
     │
     ▼
Estimated Inserts / Updates
```

### RAW Count

Counts all records available for the trading date.

```sql
SELECT COUNT(*) AS c
FROM RAW.RAW_EOD_PRICES
WHERE TRADE_DATE = (SELECT d FROM td)
```

### Reject Count

Counts records where volume is negative.

```sql
SELECT COUNT(*) AS c
FROM RAW.RAW_EOD_PRICES
WHERE TRADE_DATE = (SELECT d FROM td)
  AND VOLUME < 0
```

### Valid Keys

Only records with non-negative volume are considered valid:

```sql
SELECT DISTINCT
    UPPER(TRIM(SYMBOL)) AS SYMBOL,
    TRADE_DATE
FROM RAW.RAW_EOD_PRICES
WHERE TRADE_DATE = (SELECT d FROM td)
  AND VOLUME >= 0
```

---

## 📈 Estimated Inserts and Updates

The pipeline compares valid RAW keys against existing CORE records.

```text
Valid RAW Keys
      │
      ├── Key exists in CORE
      │        └── Estimated UPDATE
      │
      └── Key does not exist in CORE
               └── Estimated INSERT
```

The resulting metrics are:

| Metric        | Description                              |
| ------------- | ---------------------------------------- |
| `raw_cnt`     | Total RAW records for the trading date   |
| `reject_cnt`  | Records with negative volume             |
| `est_inserts` | Valid keys not currently present in CORE |
| `est_updates` | Valid keys already present in CORE       |

---

# 2️⃣ Reject Table

## 🚫 Purpose

Invalid EOD records are not loaded into the main CORE pricing table.

Instead, records with negative volume are stored in:

```text
CORE.EOD_PRICES_REJECT
```

This provides an audit trail for rejected records.

---

## 🗃️ Reject Table Structure

```sql
CREATE TABLE IF NOT EXISTS CORE.EOD_PRICES_REJECT (
    TRADE_DATE     DATE,
    SYMBOL         STRING,
    OPEN           NUMBER(18,6),
    HIGH           NUMBER(18,6),
    LOW            NUMBER(18,6),
    CLOSE          NUMBER(18,6),
    VOLUME         NUMBER(38,0),
    REJECT_REASON  STRING,
    _SRC_FILE      STRING,
    _INGEST_TS     TIMESTAMP_LTZ,
    REJECT_TS      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);
```

### Important Columns

| Column          | Purpose                                |
| --------------- | -------------------------------------- |
| `TRADE_DATE`    | Trading date of the rejected record    |
| `SYMBOL`        | Normalized security symbol             |
| `OPEN`          | Opening price                          |
| `HIGH`          | Highest price                          |
| `LOW`           | Lowest price                           |
| `CLOSE`         | Closing price                          |
| `VOLUME`        | Original volume                        |
| `REJECT_REASON` | Reason for rejection                   |
| `_SRC_FILE`     | Source file name                       |
| `_INGEST_TS`    | Original ingestion timestamp           |
| `REJECT_TS`     | Timestamp when the record was rejected |

---

# 3️⃣ CORE Merge

## 🔄 Purpose

The `merge_core.sql` file performs the main upsert from:

```text
RAW.RAW_EOD_PRICES
          │
          ▼
CORE.EOD_PRICES
```

The process handles both:

* 🚫 Invalid records
* ✅ Valid records

---

## 3.1 🚫 Capture Negative-Volume Records

Records with:

```sql
VOLUME < 0
```

are treated as rejected records.

The pipeline uses a `MERGE` into the reject table:

```sql
MERGE INTO CORE.EOD_PRICES_REJECT rej
USING (
    SELECT
        r.TRADE_DATE,
        UPPER(TRIM(r.SYMBOL)) AS SYMBOL,
        r.OPEN,
        r.HIGH,
        r.LOW,
        r.CLOSE,
        r.VOLUME,
        'NEGATIVE_VOLUME' AS REJECT_REASON,
        r._SRC_FILE,
        r._INGEST_TS
    FROM SEC_PRICING.RAW.RAW_EOD_PRICES r
    WHERE r.TRADE_DATE = ...
      AND r.VOLUME < 0
) src
```

The rejection reason is explicitly recorded as:

```text
NEGATIVE_VOLUME
```

---

## 3.2 ✅ Process Valid Records

Only records satisfying:

```sql
VOLUME >= 0
```

are allowed into the main CORE table.

```sql
FROM RAW.RAW_EOD_PRICES r
WHERE r.TRADE_DATE = ...
  AND r.VOLUME >= 0
```

This prevents invalid negative-volume records from entering:

```text
CORE.EOD_PRICES
```

---

# 3.3 🔤 Symbol Normalization

The symbol is normalized using:

```sql
UPPER(TRIM(r.SYMBOL))
```

This ensures that variations such as:

```text
aapl
 AAPL
Aapl
```

are treated consistently as:

```text
AAPL
```

This normalization is used when identifying the security key during the merge.

---

# 3.4 🔁 Deduplication

Before merging into CORE, the RAW data is ranked using:

```sql
ROW_NUMBER() OVER (
    PARTITION BY SYMBOL, TRADE_DATE
    ORDER BY
        _INGEST_TS DESC,
        _SRC_FILE DESC
)
```

The pipeline keeps:

```sql
WHERE rn = 1
```

Therefore, only one record is selected for each:

```text
(SYMBOL, TRADE_DATE)
```

combination.

### Deduplication Priority

```text
Same SYMBOL + TRADE_DATE
          │
          ▼
Latest _INGEST_TS
          │
          ▼
If tied → _SRC_FILE DESC
          │
          ▼
Keep rn = 1
```

This provides a deterministic way of selecting the record that should be loaded into CORE.

---

# 3.5 🔄 MERGE into CORE

The valid and deduplicated records are merged into:

```text
CORE.EOD_PRICES
```

The merge key is:

```text
SYMBOL + TRADE_DATE
```

Conceptually:

```text
                 RAW
                  │
                  ▼
          Normalize Symbol
                  │
                  ▼
          Remove Invalid Rows
                  │
                  ▼
             Deduplicate
                  │
                  ▼
          ┌───────────────┐
          │CORE.EOD_PRICES│
          └───────┬───────┘
                  │
          ┌───────┴────────┐
          ▼                ▼
       MATCHED          NOT MATCHED
          │                │
          ▼                ▼
       UPDATE            INSERT
```

---

## ✏️ Matched Records

When the security/date combination already exists, the existing CORE record is updated:

```sql
WHEN MATCHED THEN UPDATE SET
    OPEN    = src.OPEN,
    HIGH    = src.HIGH,
    LOW     = src.LOW,
    CLOSE   = src.CLOSE,
    VOLUME  = src.VOLUME,
    LOAD_TS = CURRENT_TIMESTAMP()
```

---

## ➕ New Records

When the security/date combination does not exist, a new record is inserted:

```sql
WHEN NOT MATCHED THEN INSERT (
    TRADE_DATE,
    SYMBOL,
    OPEN,
    HIGH,
    LOW,
    CLOSE,
    VOLUME,
    LOAD_TS
)
```

---

# 🔄 Airflow Workflow

The SQL processing is orchestrated by the Airflow DAG.

The relevant tasks are:

```text
t03_compute_premerge_metrics
             │
             ▼
     t04_merge_core_eod
```

The CORE merge is part of the larger Snowflake processing TaskGroup:

```text
t04_snowflake_load
       │
       ▼
┌───────────────────────────────┐
│ s01_copy_to_raw               │
└───────────────┬───────────────┘
                ▼
┌───────────────────────────────┐
│ s02_check_loaded_for_dt       │
└───────────────┬───────────────┘
                ▼
┌───────────────────────────────┐
│ s03_compute_premerge_metrics  │
└───────────────┬───────────────┘
                ▼
┌───────────────────────────────┐
│ s04_merge_core_eod            │
└───────────────┬───────────────┘
                ▼
       Dimension Processing
```

The DAG passes the trading date through:

```text
t01_download_to_csv
        │
        │ XCom
        ▼
trading_date
        │
        ▼
Snowflake SQL
```

---

# 🛡️ Data Quality and Reject Handling

The CORE load applies a basic data-quality rule:

```text
VOLUME < 0
     │
     ▼
REJECT
```

while:

```text
VOLUME >= 0
     │
     ▼
VALID
     │
     ▼
CORE.EOD_PRICES
```

This prevents known-invalid volume values from entering the production CORE pricing table.

---

## 🧪 Example Reject Validation

To inspect rejected records:

```sql
SELECT *
FROM CORE.EOD_PRICES_REJECT;
```

To count rejected records:

```sql
SELECT COUNT(*) AS rejected_rows
FROM CORE.EOD_PRICES_REJECT;
```

To inspect negative-volume records in RAW:

```sql
SELECT *
FROM SEC_PRICING.RAW.RAW_EOD_PRICES
WHERE VOLUME < 0;
```

---

# 🔁 Idempotency

The CORE load is designed to be idempotent for a trading date.

The merge uses:

```text
SYMBOL + TRADE_DATE
```

as the logical business key.

Therefore, reprocessing the same trading date does not create duplicate CORE records for the same security/date combination.

The RAW data is also deduplicated before the CORE merge using:

```text
_SYMBOL
TRADE_DATE
_INGEST_TS
_SRC_FILE
```

with the latest ingestion timestamp selected first.

---

# 📊 Processing Metrics

The pipeline produces metrics before and after the CORE processing.

## Pre-Merge

```text
RAW rows
   │
   ├── Reject rows
   │
   ├── Estimated INSERT rows
   │
   └── Estimated UPDATE rows
```

## Post-Merge

The downstream post-merge step provides the final CORE and FACT row counts.

These metrics are later consumed by the Airflow Slack summary task.

The resulting operational summary contains:

```text
Trading Date
RAW rows
Reject rows
Estimated CORE inserts
Estimated CORE updates
CORE rows after merge
FACT rows after merge
```

This provides a compact view of the EOD pipeline execution.

---

# 📁 Related Source Files

| Resource                 | Link                                                                          |
| ------------------------ |-------------------------------------------------------------------------------|
| 🔄 CORE Merge SQL        | [`4. merge_core.sql`](../../airflow/dags/sql/4.%20merge_core.sql)             |
| 📊 Pre-Merge Metrics     | [`3. premerge_metrics.sql`](../../airflow/dags/sql/3.%20premerge_metrics.sql) |
| 🚫 Reject Table Creation | [`reject_table_creation.sql`](../../snowflake/07_reject/reject_table_creation.sql) |
| ⚙️ Airflow EOD DAG       | [`daily_eod_ingestion_dag.py`](../../airflow/dags/daily_eod_ingestion_dag.py) |
| 📥 EOD Data Downloader   | [`eod_data_downloader.py`](../../airflow/dags/lib/eod_data_downloader.py) |

> **Note:** Update the `reject_table_creation.sql` path if the SQL file is stored in a different directory in the repository.

---

# 🎤 Interview Questions

### 1. Why is a MERGE used for the CORE EOD load?

`MERGE` allows the pipeline to handle both existing and new security/date records in a single operation.

Existing records are updated, while new records are inserted.

---

### 2. What happens to records with negative volume?

Records with negative volume are excluded from the CORE load and captured in:

```text
CORE.EOD_PRICES_REJECT
```

with the rejection reason:

```text
NEGATIVE_VOLUME
```

---

### 3. Why is `UPPER(TRIM(SYMBOL))` used?

It normalizes security symbols so that differences in case or leading/trailing spaces do not result in inconsistent keys.

---

### 4. Why is `ROW_NUMBER()` used before the MERGE?

It deduplicates RAW records so that only one record exists for each:

```text
SYMBOL + TRADE_DATE
```

combination before the MERGE.

---

### 5. How is the winning duplicate selected?

The latest `_INGEST_TS` is selected first.

If timestamps are equal, `_SRC_FILE` is used as a deterministic tie-breaker.

---

### 6. What is the purpose of pre-merge metrics?

Pre-merge metrics provide an estimate of:

* RAW records
* Rejected records
* Expected inserts
* Expected updates

before the CORE table is modified.

---

### 7. How does the pipeline maintain idempotency?

The CORE table is merged using the logical key:

```text
SYMBOL + TRADE_DATE
```

and duplicate RAW records are removed before the merge.

Re-running the same trading date therefore does not create duplicate CORE records.

---

### 8. Why keep a reject table?

A reject table preserves invalid records for:

* Data-quality analysis
* Troubleshooting
* Auditing
* Operational monitoring

instead of silently discarding them.

---

# 🎉 Result

The CORE processing stage provides a controlled and repeatable EOD loading mechanism:

```text
                 RAW EOD DATA
                       │
                       ▼
              📊 PRE-MERGE CHECK
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
       🚫 Invalid             ✅ Valid
       Volume < 0             Volume >= 0
             │                   │
             ▼                   ▼
      REJECT TABLE          Normalize Symbol
                                 │
                                 ▼
                            Deduplicate
                                 │
                                 ▼
                           CORE MERGE
                           ┌─────┴─────┐
                           ▼           ▼
                        UPDATE       INSERT
                           │           │
                           └─────┬─────┘
                                 ▼
                         CORE.EOD_PRICES
```