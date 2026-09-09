# 🔄 Incremental Daily Processing

![Apache Airflow](https://img.shields.io/badge/Apache%20Airflow-Workflow%20Orchestration-017CEE?logo=apacheairflow&logoColor=white)
![Amazon S3](https://img.shields.io/badge/Amazon%20S3-Bronze%20Storage-FF9900?logo=amazons3&logoColor=white)
![Snowflake](https://img.shields.io/badge/Snowflake-Data%20Processing-29B5E8?logo=snowflake&logoColor=white)
![Python](https://img.shields.io/badge/Python-Data%20Pipeline-3776AB?logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Data%20Transformation-CC2927?logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Airflow%20Environment-2496ED?logo=docker&logoColor=white)

This section documents the automated daily **End-of-Day (EOD) securities
pricing pipeline** using **Apache Airflow, AWS S3, and Snowflake**.

The incremental pipeline retrieves daily market data from the **Massive API**,
generates an EOD CSV file, uploads the file to the **Amazon S3 Bronze layer**,
and incrementally processes the data through the Snowflake **RAW, CORE,
DIMENSION, and FACT layers**.

The pipeline also performs data-quality validation, reject handling,
pre/post-merge metrics, and sends an EOD execution summary to **Slack**.

---

## 📚 Documentation

### 1. Airflow EOD Ingestion

[`01_airflow_eod_ingestion.md`](01_airflow_eod_ingestion.md)

Covers:

- Apache Airflow DAG
- Massive API
- Daily EOD data download
- Airflow Variables
- XCom
- Task dependencies
- Retry handling
- Local CSV generation
- Local CSV validation
- Trading-date resolution

---

### 2. AWS S3 & Airflow Connection

[`02_aws_s3_airflow_connection.md`](02_aws_s3_airflow_connection.md)

Covers:

- AWS S3 bucket
- IAM user
- S3 permissions
- AWS access keys
- Airflow AWS Connection
- `aws_default`
- S3 connectivity
- Airflow → S3 authentication

---

### 3. Upload EOD Data to S3

[`03_upload_eod_data_to_s3.md`](03_upload_eod_data_to_s3.md)

Covers:

- Airflow S3 upload task
- `LocalFilesystemToS3Operator`
- XCom-based trading date
- Local CSV file
- S3 destination key
- S3 Bronze layer
- `replace=True`
- Upload task dependencies
- EOD file validation

Expected S3 location:

```text
s3://rdf-stock-daily-eod-1/market/bronze/eod/
````

Example:

```text
eod_prices_2026-09-08.csv
```

---

### 4. Snowflake S3 Storage Integration & External Stage

[`04_snowflake_s3_stage.md`](04_snowflake_s3_stage.md)

Covers:

* AWS IAM Role
* S3 permissions
* IAM trust relationship
* Snowflake External ID
* Snowflake Storage Integration
* `INT_S3_AIRFLOWSNOWDE`
* S3 allowed locations
* Snowflake External Stage
* `STG_S3_BRONZE`
* Snowflake → S3 connectivity
* External stage validation

---

### 5. Snowflake & Airflow Connection

[`05_snowflake_airflow_connection.md`](05_snowflake_airflow_connection.md)

Covers:

* Airflow Connections
* Snowflake connection
* Connection ID
* `snowflake_default`
* Snowflake connection configuration
* Airflow → Snowflake authentication
* Snowflake connection verification
* Test DAG
* Connection validation

---

### 6. Snowflake S3 → RAW Data Load

[`06_snowflake_s3_to_raw_load.md`](06_snowflake_s3_to_raw_load.md)

Covers:

* Snowflake External Stage
* S3 Bronze → Snowflake RAW
* `COPY INTO`
* EOD file loading
* `snowflake_default`
* Airflow `SQLExecuteQueryOperator`
* RAW data validation
* EOD trading-date validation
* Pre-merge metrics
* Snowflake TaskGroup

Main Airflow tasks:

```text
s01_copy_to_raw
        │
        ▼
s02_check_eod_prices_exist
        │
        ▼
s03_compute_premerge_metrics
```

---

### 7. Snowflake CORE Merge

[`07_snowflake_core_merge.md`](07_snowflake_core_merge.md)

Covers:

* RAW → CORE processing
* Pre-merge metrics
* Insert estimation
* Update estimation
* Negative-volume validation
* Reject handling
* Symbol normalization
* Duplicate handling
* `ROW_NUMBER()`
* Snowflake `MERGE`
* CORE inserts
* CORE updates
* Idempotent EOD processing

Main processing:

```text
RAW EOD Data
     │
     ▼
Pre-Merge Metrics
     │
     ▼
CORE MERGE
     │
     ├───────────────┐
     ▼               ▼
  INSERT           UPDATE
     │               │
     └───────┬───────┘
             ▼
       CORE.EOD_PRICES
```

---

### 8. Rejection Data & Dimension/Fact Processing

[`08_rejection_data_merge.md`](08_rejection_data_merge.md)

Covers:

* Invalid EOD record handling
* Reject data processing
* Security dimension merge
* Date dimension merge
* Daily price fact merge
* Post-merge metrics
* CORE → DIM → FACT processing
* Airflow task dependencies

The Snowflake processing follows:

```text
CORE MERGE
     │
     ├──────────────────┐
     ▼                  ▼
Security Dimension   Date Dimension
     │                  │
     └────────┬─────────┘
              ▼
       Daily Price Fact
              │
              ▼
       Post-Merge Metrics
```
---

# 🏗️ Incremental EOD Pipeline

```text
                         Massive API
                              │
                              ▼
                       Apache Airflow
                              │
                              ▼
                     Download EOD Data
                              │
                              ▼
                         Local CSV
                              │
                              ▼
                      Verify CSV File
                              │
                              ▼
                         Amazon S3
                       Bronze Layer
                              │
                              ▼
                Snowflake Storage Integration
                              │
                              ▼
                   Snowflake External Stage
                              │
                              ▼
                            RAW
                              │
                              ▼
                     Pre-Merge Validation
                              │
                              ▼
                       CORE MERGE
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
             Security Dimension    Date Dimension
                    │                   │
                    └─────────┬─────────┘
                              │
                              ▼
                     Daily Price FACT
                              │
                              ▼
                    Post-Merge Metrics

```

---

# 🔄 Airflow Task Flow

The complete Airflow workflow is organized into the following stages:

```text
t01_download_to_csv
        │
        ▼
t02_verify_local_file
        │
        ▼
t03_upload_to_s3
        │
        ▼
┌─────────────────────────────────────┐
│        t04_snowflake_load           │
│                                     │
│  s01_copy_to_raw                    │
│          │                          │
│          ▼                          │
│  s02_check_eod_prices_exist         │
│          │                          │
│          ▼                          │
│  s03_compute_premerge_metrics       │
│          │                          │
│          ▼                          │
│  s04_merge_core_eod                 │
│          │                          │
│     ┌────┴─────┐                    │
│     ▼          ▼                    │
│  s05_dim     s06_dim                │
│  security    date                   │
│     │          │                    │
│     └────┬─────┘                    │
│          ▼                          │
│  s07_merge_fact_daily_price         │
│          │                          │
│          ▼                          │
│  s08_compute_postmerge_metrics      │
└─────────────────────────────────────┘
```

---

# 🔗 Snowflake Processing Dependencies

The Snowflake tasks use the following dependency structure:

```text
copy_to_raw
     │
     ▼
check_loaded
     │
     ▼
premerge_metrics
     │
     ▼
merge_core
     │
     ├──────────────────────┐
     ▼                      ▼
merge_dim_security    merge_dim_date
     │                      │
     └──────────┬───────────┘
                ▼
        merge_fact_daily_price
                │
                ▼
        postmerge_metrics
```

The security and date dimension tasks run **in parallel** after the CORE
merge and both must complete before the daily price fact is processed.

---

# 📊 Data Layers

The incremental pipeline uses the following data layers:

| Layer     | Technology  | Purpose                           |
| --------- | ----------- | --------------------------------- |
| 📥 Source | Massive API | Daily market EOD data             |
| 🪣 Bronze | Amazon S3   | Raw EOD CSV storage               |
| 🗃️ RAW   | Snowflake   | Raw ingested pricing data         |
| 🔄 CORE   | Snowflake   | Validated and merged pricing data |
| 📐 DIM    | Snowflake   | Security and date dimensions      |
| 📈 FACT   | Snowflake   | Daily pricing fact data           |

---

# 🛡️ Data Quality

The pipeline includes validation before data reaches downstream tables.

Key validations include:

* ✅ Local EOD CSV existence
* ✅ RAW data availability
* ✅ Trading-date validation
* ✅ Negative-volume detection
* ✅ Reject record handling
* ✅ Duplicate key handling
* ✅ Pre-merge insert/update metrics
* ✅ Post-merge row-count validation

Invalid records are separated from valid CORE processing.

```text
             RAW DATA
                 │
        ┌────────┴────────┐
        │                 │
   Volume < 0        Volume >= 0
        │                 │
        ▼                 ▼
     REJECT             CORE
        │                 │
        │                 ▼
        │             DIMENSIONS
        │                 │
        │                 ▼
        │                FACT
        │
        └──► Audit / Investigation
```

---

# 🔁 Incremental Processing

The pipeline processes the **latest available trading day** rather than
reprocessing the entire historical dataset.

The trading date is passed through Airflow using **XCom** and reused by
downstream tasks.

```text
Airflow
   │
   ▼
Trading Date
   │
   ├──────────────► Local CSV
   │
   ├──────────────► S3 Path
   │
   ├──────────────► RAW Load
   │
   └──────────────► CORE Merge
```

---

# 📈 Monitoring

The pipeline provides monitoring at multiple stages.

### Airflow

Airflow provides:

* Task status
* DAG execution status
* Task retries
* Execution duration
* Task logs

### Snowflake

Snowflake processing provides:

* RAW row counts
* Reject counts
* Estimated inserts
* Estimated updates
* CORE row counts
* FACT row counts

---

# 🧰 Technologies Used

| Technology         | Usage                                     |
| ------------------ | ----------------------------------------- |
| 🐍 Python          | EOD data extraction and Airflow utilities |
| ⚙️ Apache Airflow  | Workflow orchestration                    |
| 📊 Massive API     | Market EOD data source                    |
| ☁️ Amazon S3       | Bronze data storage                       |
| 🔐 AWS IAM         | AWS access and permissions                |
| ❄️ Snowflake       | Data warehouse and processing             |
| 🔄 Snowflake MERGE | Incremental upsert processing             |
| 🔔 Slack           | Pipeline notifications                    |
| 🐳 Docker          | Local Airflow environment                 |

---

# 🎯 Key Features

* 🔄 Incremental daily EOD processing
* 📅 Trading-date based processing
* 📥 Massive API extraction
* 📄 Automated CSV generation
* ☁️ S3 Bronze layer storage
* 🔐 AWS IAM-based access
* ❄️ Snowflake external stage
* 📥 RAW data loading
* 🔄 CORE incremental merge
* 🚫 Reject handling
* 📊 Pre/post merge metrics
* 📐 Dimension processing
* 📈 Fact table processing
* 🔔 Slack notifications
* 🔁 Airflow retry handling
* 🛡️ Data-quality validation
* ♻️ Idempotent processing

---


# 🎉 Final Result

The completed incremental EOD pipeline automates the complete journey from
market-data extraction to operational notification:

```text
                    Massive API
                         │
                         ▼
                 Apache Airflow
                         │
                         ▼
                    Local CSV
                         │
                         ▼
                   Amazon S3
                 Bronze Layer
                         │
                         ▼
              Snowflake External Stage
                         │
                         ▼
                       RAW
                         │
                         ▼
                      CORE
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
       Security DIM             Date DIM
              │                     │
              └──────────┬──────────┘
                         ▼
                   Daily FACT
                         │
                         ▼
                Post-Merge Metrics
                         │
                         ▼
                      Slack
                         │
                         ▼
                 EOD Summary
```