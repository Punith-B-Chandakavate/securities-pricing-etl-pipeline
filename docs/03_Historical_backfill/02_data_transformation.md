# 🔄 Historical Data Transformation — Snowflake

![Snowflake](https://img.shields.io/badge/Snowflake-Data%20Warehouse-29B5E8?logo=snowflake&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Snowflake-blue)
![Data Engineering](https://img.shields.io/badge/Data%20Engineering-ETL-orange)
![Data Modeling](https://img.shields.io/badge/Data%20Modeling-Dimensional%20Modeling-green)

---

# 📖 Overview

After the historical EOD pricing data is loaded into the Snowflake
RAW layer, the data is transformed into a structured analytical
data model.

The transformation process moves the data through the following
Snowflake layers:

```text
RAW
 ↓
CORE
 ↓
DIMENSIONS
 ↓
FACT
````

The transformation standardizes and deduplicates the raw pricing
data, creates reusable security and date dimensions, and finally
builds the daily EOD pricing fact table.

This creates a clean foundation for downstream analytics,
reporting, and Power BI dashboards.

---

# 🎯 Objectives

The main objectives of this transformation process are:

* Standardize raw security symbols.
* Remove unnecessary spaces from security identifiers.
* Convert symbols to a consistent uppercase format.
* Remove duplicate EOD pricing records.
* Keep the latest ingested pricing record.
* Create a reusable Security Dimension.
* Create a reusable Date Dimension.
* Generate surrogate keys for dimensions.
* Build the Daily EOD Pricing Fact table.
* Maintain the expected fact table grain.
* Use `MERGE` operations for inserts and updates.
* Validate the transformed data at each layer.

---

# 🏗️ Snowflake Transformation Architecture

The historical data flows through the warehouse as follows:

```text
                  Historical CSV
                        │
                        ▼
              ┌───────────────────┐
              │       RAW         │
              │                   │
              │ RAW_EOD_PRICES    │
              └─────────┬─────────┘
                        │
                        │ Clean
                        │ Standardize
                        │ Deduplicate
                        ▼
              ┌───────────────────┐
              │       CORE        │
              │                   │
              │ EOD_PRICES        │
              └─────────┬─────────┘
                        │
                 ┌──────┴──────┐
                 │             │
                 ▼             ▼
        ┌────────────────┐  ┌────────────────┐
        │ DM_DIM         │  │ DM_DIM         │
        │ DIM_SECURITY   │  │ DIM_DATE       │
        └───────┬────────┘  └───────┬────────┘
                │                   │
                └─────────┬─────────┘
                          │
                          ▼
                ┌───────────────────┐
                │      DM_FACT      │
                │                   │
                │ FACT_DAILY_PRICE  │
                └─────────┬─────────┘
                          │
                          ▼
                    SA / Analytics
                          │
                          ▼
                       Power BI
```

---

# 📂 SQL Implementation

The transformation process is implemented using the following
Snowflake SQL scripts:

| Layer | SQL File | Purpose |
|------|----------|---------|
| CORE | [`02_transform_raw_to_core_eod_prices.sql`](../../snowflake/03_core/02_transform_raw_to_core_eod_prices.sql) | Transform, standardize, deduplicate, and merge RAW pricing data into CORE |
| Dimension | [`02_dim_security.sql`](../../snowflake/04_dimension/02_dim_security.sql) | Populate the Security Dimension |
| Dimension | [`03_dim_date.sql`](../../snowflake/04_dimension/03_dim_date.sql) | Populate the Date Dimension |
| Fact | [`02_fact_eod_pricing.sql`](../../snowflake/05_fact/02_fact_eod_pricing.sql) | Populate the Daily EOD Pricing Fact |
---

# 1️⃣ RAW → CORE Transformation

## 📄 SQL File

```text
snowflake/03_core/02_transform_raw_to_core_eod_prices.sql
```

The first transformation moves the historical pricing data from
the RAW layer into the CORE layer.

The CORE layer contains standardized and deduplicated EOD pricing
records that can be used by downstream dimensions and fact tables.

---

## Source

```text
SEC_PRICING.RAW.RAW_EOD_PRICES
```

## Target

```text
SEC_PRICING.CORE.EOD_PRICES
```

## Business Key

```text
TRADE_DATE + SYMBOL
```

The combination of `TRADE_DATE` and `SYMBOL` identifies the expected
unique EOD pricing record.

---

# 🔄 CORE Transformation Flow

```text
RAW.RAW_EOD_PRICES
        │
        ▼
     SRC_RAW
        │
        │ TRIM()
        │ UPPER()
        ▼
Standardized Symbols
        │
        ▼
      RANKED
        │
        │ ROW_NUMBER()
        │
        ▼
Latest Record
        │
        │ WHERE rn = 1
        ▼
       MERGE
      /       \
     /         \
MATCHED      NOT MATCHED
   │              │
 UPDATE          INSERT
   │              │
   └──────┬───────┘
          ▼
CORE.EOD_PRICES
```

---

# 🧹 CTE 1 — `SRC_RAW`

The `SRC_RAW` CTE prepares the RAW data before the deduplication
process.

It is used to perform the initial standardization of security
symbols and retain metadata required for duplicate handling.

```sql
WITH SRC_RAW AS (
    SELECT
        r.TRADE_DATE,
        UPPER(TRIM(r.SYMBOL)) AS SYMBOL,
        r.OPEN,
        r.HIGH,
        r.LOW,
        r.CLOSE,
        r.VOLUME,
        r._INGEST_TS,
        r._SRC_FILE
    FROM RAW.RAW_EOD_PRICES r
)
```

---

## Why is `SRC_RAW` used?

The purpose of this CTE is to create a **clean source dataset**
before applying further transformations.

The security symbol is standardized using:

```sql
UPPER(TRIM(r.SYMBOL))
```

This performs two transformations.

### Step 1 — `TRIM()`

Removes leading and trailing spaces.

```text
"  AAPL  "
     ↓
"AAPL"
```

### Step 2 — `UPPER()`

Converts the symbol to uppercase.

```text
"aapl"
  ↓
"AAPL"
```

Therefore:

```text
"  aapl  "
      ↓
   TRIM()
      ↓
    "aapl"
      ↓
   UPPER()
      ↓
    "AAPL"
```

This ensures that security symbols have a consistent representation
before they are used as business keys.

---

# 🔢 CTE 2 — `RANKED`

The `RANKED` CTE is responsible for identifying duplicate records
and determining which record should be retained.

```sql
ROW_NUMBER() OVER (
    PARTITION BY TRADE_DATE, SYMBOL
    ORDER BY _INGEST_TS DESC, _SRC_FILE DESC
) AS rn
```

---

## Why is `RANKED` used?

The RAW layer may contain multiple records for the same:

```text
TRADE_DATE + SYMBOL
```

The `ROW_NUMBER()` function assigns a ranking to these records.

The records are grouped using:

```sql
PARTITION BY TRADE_DATE, SYMBOL
```

The latest ingestion is placed first using:

```sql
ORDER BY _INGEST_TS DESC
```

If two records have the same ingestion timestamp, the source file
is used as a deterministic tie-breaker:

```sql
_SRC_FILE DESC
```

---

## Example

Suppose RAW contains:

| TRADE_DATE | SYMBOL |  CLOSE | _INGEST_TS |
| ---------- | ------ | -----: | ---------- |
| 2026-08-03 | AAPL   | 201.20 | 10:00      |
| 2026-08-03 | AAPL   | 202.50 | 11:00      |
| 2026-08-03 | AAPL   | 203.10 | 12:00      |

After applying `ROW_NUMBER()`:

| TRADE_DATE | SYMBOL |  CLOSE | _INGEST_TS | RN |
| ---------- | ------ | -----: | ---------- | -: |
| 2026-08-03 | AAPL   | 203.10 | 12:00      |  1 |
| 2026-08-03 | AAPL   | 202.50 | 11:00      |  2 |
| 2026-08-03 | AAPL   | 201.20 | 10:00      |  3 |

The transformation keeps:

```sql
WHERE rn = 1
```

Therefore, only the latest record is selected.

---

# 🔀 CORE `MERGE`

After cleaning and deduplication, the transformed data is merged
into:

```text
CORE.EOD_PRICES
```

The matching condition is:

```sql
ON EP.SYMBOL = LP.SYMBOL
AND EP.TRADE_DATE = LP.TRADE_DATE
```

This uses:

```text
TRADE_DATE + SYMBOL
```

as the business key.

---

## Existing Record

If the record already exists:

```text
WHEN MATCHED
      ↓
   UPDATE
```

The pricing values are updated.

---

## New Record

If the record does not exist:

```text
WHEN NOT MATCHED
      ↓
    INSERT
```

A new CORE record is created.

---

# 2️⃣ Build Security Dimension

## 📄 SQL File

```text
snowflake/04_dimension/02_dim_security.sql
```

The Security Dimension provides a unique identifier for every
security available in the CORE pricing data.

---

## Source

```text
CORE.EOD_PRICES
```

## Target

```text
DM_DIM.DIM_SECURITY
```

## Business Key

```text
SYMBOL
```

---

# 🔄 Security Dimension Flow

```text
CORE.EOD_PRICES
       │
       ▼
SELECT DISTINCT SYMBOL
       │
       ▼
Unique Securities
       │
       ▼
ROW_NUMBER()
       │
       ▼
SECURITY_ID
       │
       ▼
MERGE
       │
       ▼
DM_DIM.DIM_SECURITY
```

---

# 🧹 Remove Duplicate Securities

The CORE table contains multiple records for a security because
each security has pricing information for multiple trading dates.

For example:

```text
AAPL | 2026-08-03
AAPL | 2026-08-04
AAPL | 2026-08-05
MSFT | 2026-08-03
MSFT | 2026-08-04
```

Using:

```sql
SELECT DISTINCT SYMBOL
FROM CORE.EOD_PRICES
```

produces:

```text
AAPL
MSFT
```

This ensures that each security appears only once in the dimension.

---

# 🔢 Generate `SECURITY_ID`

A sequential identifier is generated using:

```sql
ROW_NUMBER() OVER (ORDER BY SYMBOL)
```

Example:

| SECURITY_ID | SYMBOL |
| ----------: | ------ |
|           1 | AAPL   |
|           2 | MSFT   |
|           3 | NVDA   |

The generated `SECURITY_ID` is then inserted into:

```text
DM_DIM.DIM_SECURITY
```

---

# 3️⃣ Build Date Dimension

## 📄 SQL File

```text
snowflake/04_dimension/03_dim_date.sql
```

The Date Dimension provides reusable calendar attributes for
reporting and analytical queries.

---

## Source

```text
CORE.EOD_PRICES
```

## Target

```text
DM_DIM.DIM_DATE
```

## Business Key

```text
DATE_SK
```

---

# 🔄 Date Dimension Flow

```text
CORE.EOD_PRICES
       │
       ▼
Unique TRADE_DATE
       │
       ▼
Generate DATE_SK
       │
       ├── YEAR_NUM
       ├── QUARTER_NUM
       ├── MONTH_NUM
       ├── MONTH_NAME
       ├── DAY_NUM
       ├── DAY_NAME
       ├── DAY_OF_WEEK
       ├── WEEK_OF_YEAR
       └── IS_WEEKEND
       │
       ▼
MERGE
       │
       ▼
DM_DIM.DIM_DATE
```

---

# 🔑 Generate `DATE_SK`

The date surrogate key is generated using:

```sql
TO_NUMBER(
    TO_CHAR(e.TRADE_DATE, 'YYYYMMDD')
)
```

Example:

```text
2026-08-03
    ↓
20260803
```

Therefore:

```text
DATE_SK = 20260803
```

---

# 📅 Calendar Attributes

The Date Dimension contains commonly used calendar attributes:

| Column         | Description           |
| -------------- | --------------------- |
| `DATE_SK`      | Surrogate date key    |
| `CAL_DATE`     | Trading/calendar date |
| `YEAR_NUM`     | Year                  |
| `QUARTER_NUM`  | Quarter               |
| `MONTH_NUM`    | Month number          |
| `MONTH_NAME`   | Month name            |
| `DAY_NUM`      | Day of month          |
| `DAY_NAME`     | Day name              |
| `DAY_OF_WEEK`  | Numeric day of week   |
| `WEEK_OF_YEAR` | Week number           |
| `IS_WEEKEND`   | Weekend indicator     |

These attributes can be used directly in reporting and Power BI
without repeatedly calculating calendar values.

---

# 4️⃣ Build Daily EOD Pricing Fact

## 📄 SQL File

```text
snowflake/05_fact/02_fact_eod_pricing.sql
```

The Daily EOD Pricing Fact table stores the daily OHLCV pricing
information for each security.

---

## Source Tables

```text
CORE.EOD_PRICES
DM_DIM.DIM_SECURITY
DM_DIM.DIM_DATE
```

## Target

```text
DM_FACT.FACT_DAILY_PRICE
```

---

# 📌 Fact Table Grain

The fact table has the following grain:

```text
One row per SECURITY_ID + DATE_SK
```

This means a single record represents:

> One security on one trading date.

---

## Example

| SECURITY_ID |  DATE_SK |  CLOSE |   VOLUME |
| ----------: | -------: | -----: | -------: |
|           1 | 20260803 | 201.20 | 52000000 |
|           1 | 20260804 | 203.50 | 48000000 |
|           2 | 20260803 | 501.20 | 31000000 |

The combination:

```text
SECURITY_ID + DATE_SK
```

identifies the daily pricing record.

---

# 🔗 Security Dimension Lookup

The fact transformation joins CORE with `DIM_SECURITY`:

```sql
JOIN DM_DIM.DIM_SECURITY ds
    ON ds.SYMBOL = e.SYMBOL
```

This converts the natural security identifier:

```text
SYMBOL
```

into the dimension key:

```text
SECURITY_ID
```

Example:

```text
AAPL
  ↓
SECURITY_ID = 1
```

The fact table therefore stores the dimension key instead of
relying only on the natural security symbol.

---

# 🔗 Date Dimension Lookup

The trading date is converted into the corresponding `DATE_SK`:

```sql
TO_NUMBER(
    TO_CHAR(e.TRADE_DATE, 'YYYYMMDD')
)
```

The generated key is matched with:

```text
DM_DIM.DIM_DATE
```

This establishes the relationship:

```text
TRADE_DATE
    ↓
DATE_SK
```

---

# 🔀 Fact Table `MERGE`

The fact table uses:

```sql
ON f.SECURITY_ID = src.SECURITY_ID
AND f.DATE_SK = src.DATE_SK
```

This defines the fact table business key:

```text
SECURITY_ID + DATE_SK
```

---

## Existing Fact Record

When the security/date combination already exists:

```text
WHEN MATCHED
      ↓
    UPDATE
```

The pricing measures are updated:

```text
OPEN
HIGH
LOW
CLOSE
VOLUME
```

The load timestamp is also refreshed:

```sql
CURRENT_TIMESTAMP()
```

---

## New Fact Record

When the security/date combination does not exist:

```text
WHEN NOT MATCHED
      ↓
    INSERT
```

A new daily pricing record is inserted.

---

# 🧩 Final Data Model

The resulting Snowflake model can be represented as:

```text
                  DIM_SECURITY
                ┌───────────────┐
                │ SECURITY_ID   │
                │ SYMBOL        │
                └───────┬───────┘
                        │
                        │
                        ▼
              FACT_DAILY_PRICE
             ┌──────────────────┐
             │ SECURITY_ID      │
             │ DATE_SK          │
             │ TRADE_DATE       │
             │ OPEN             │
             │ HIGH             │
             │ LOW              │
             │ CLOSE            │
             │ VOLUME           │
             │ LOAD_TS          │
             └────────┬─────────┘
                      │
                      │
                      ▼
                  DIM_DATE
                ┌───────────────┐
                │ DATE_SK       │
                │ CAL_DATE      │
                │ YEAR_NUM      │
                │ QUARTER_NUM   │
                │ MONTH_NUM     │
                │ MONTH_NAME    │
                │ DAY_NUM       │
                │ DAY_NAME      │
                │ DAY_OF_WEEK   │
                │ WEEK_OF_YEAR  │
                │ IS_WEEKEND    │
                └───────────────┘
```

---

# 🔄 Complete Historical Transformation Flow

The complete process is:

```text
                         Massive API
                             │
                             ▼
                      Historical CSV
                             │
                             ▼
                    RAW.RAW_EOD_PRICES
                             │
                             │
                 ┌───────────┴───────────┐
                 │                       │
                 │ TRIM + UPPER          │
                 │ Deduplication         │
                 │ Latest ingestion      │
                 │                       │
                 └───────────┬───────────┘
                             ▼
                     CORE.EOD_PRICES
                             │
                    ┌────────┴────────┐
                    │                 │
                    ▼                 ▼
             DIM_SECURITY          DIM_DATE
                    │                 │
                    │ SECURITY_ID     │ DATE_SK
                    │                 │
                    └────────┬────────┘
                             │
                             ▼
                  FACT_DAILY_PRICE
                             │
                             ▼
                       SA / Analytics
                             │
                             ▼
                          Power BI
```

---

# 🧪 Data Validation

After each transformation, validate the target table.

---

## CORE Validation

```sql
SELECT COUNT(*) AS TOTAL_ROWS
FROM SEC_PRICING.CORE.EOD_PRICES;
```

Inspect the records:

```sql
SELECT *
FROM SEC_PRICING.CORE.EOD_PRICES
LIMIT 10;
```

Check the date range:

```sql
SELECT
    MIN(TRADE_DATE) AS MIN_TRADE_DATE,
    MAX(TRADE_DATE) AS MAX_TRADE_DATE
FROM SEC_PRICING.CORE.EOD_PRICES;
```

---

# 🔍 CORE Duplicate Check

The expected business key is:

```text
TRADE_DATE + SYMBOL
```

Validate that there are no duplicates:

```sql
SELECT
    TRADE_DATE,
    SYMBOL,
    COUNT(*) AS RECORD_COUNT
FROM SEC_PRICING.CORE.EOD_PRICES
GROUP BY TRADE_DATE, SYMBOL
HAVING COUNT(*) > 1;
```

The expected result is:

```text
No rows
```

---

# 🔍 Security Dimension Validation

Check the number of securities:

```sql
SELECT COUNT(*) AS TOTAL_SECURITIES
FROM SEC_PRICING.DM_DIM.DIM_SECURITY;
```

Inspect the dimension:

```sql
SELECT *
FROM SEC_PRICING.DM_DIM.DIM_SECURITY
ORDER BY SECURITY_ID;
```

Check duplicate symbols:

```sql
SELECT
    SYMBOL,
    COUNT(*) AS RECORD_COUNT
FROM SEC_PRICING.DM_DIM.DIM_SECURITY
GROUP BY SYMBOL
HAVING COUNT(*) > 1;
```

Expected result:

```text
No rows
```

---

# 🔍 Date Dimension Validation

Check the number of dates:

```sql
SELECT COUNT(*) AS TOTAL_DATES
FROM SEC_PRICING.DM_DIM.DIM_DATE;
```

Inspect the dates:

```sql
SELECT *
FROM SEC_PRICING.DM_DIM.DIM_DATE
ORDER BY DATE_SK;
```

---

# 🔍 Fact Table Validation

Check the total number of records:

```sql
SELECT COUNT(*) AS TOTAL_ROWS
FROM SEC_PRICING.DM_FACT.FACT_DAILY_PRICE;
```

Inspect the fact table:

```sql
SELECT *
FROM SEC_PRICING.DM_FACT.FACT_DAILY_PRICE;
```

---

# 🔍 Fact Duplicate Check

The expected fact grain is:

```text
SECURITY_ID + DATE_SK
```

Validate that there are no duplicate combinations:

```sql
SELECT
    SECURITY_ID,
    DATE_SK,
    COUNT(*) AS RECORD_COUNT
FROM SEC_PRICING.DM_FACT.FACT_DAILY_PRICE
GROUP BY SECURITY_ID, DATE_SK
HAVING COUNT(*) > 1;
```

Expected result:

```text
No rows
```

---

# 📊 Layer-by-Layer Validation

| Layer        | Validation                | Expected Result            |
| ------------ | ------------------------- | -------------------------- |
| RAW          | Historical records loaded | Records available          |
| CORE         | Symbols standardized      | Consistent symbols         |
| CORE         | Duplicate check           | No duplicate business keys |
| DIM_SECURITY | Unique symbols            | One row per security       |
| DIM_DATE     | Unique dates              | One row per date           |
| FACT         | Security/date grain       | One row per security/date  |
| FACT         | Pricing measures          | OHLCV populated            |
| FACT         | Load timestamp            | `LOAD_TS` populated        |

---

# 🧠 Key Data Engineering Concepts

This transformation phase demonstrates the following Data Engineering
concepts:

### Data Standardization

```sql
UPPER(TRIM(SYMBOL))
```

Used to maintain consistent security identifiers.

### Deduplication

```sql
ROW_NUMBER() OVER (
    PARTITION BY TRADE_DATE, SYMBOL
    ORDER BY _INGEST_TS DESC
)
```

Used to identify and retain the latest record.

### CTEs

CTEs such as:

```text
SRC_RAW
RANKED
```

break complex transformations into logical and readable steps.

### MERGE / UPSERT

Used to:

```text
MATCHED
    ↓
UPDATE

NOT MATCHED
    ↓
INSERT
```

### Surrogate Keys

The model generates:

```text
SECURITY_ID
DATE_SK
```

for dimension and fact relationships.

### Dimensional Modeling

The warehouse separates:

```text
Dimensions
    ↓
Security
Date

Fact
    ↓
Daily Pricing
```

### Fact Table Grain

The fact table is defined at:

```text
SECURITY_ID + DATE_SK
```

representing one security's EOD price for one trading date.

---
