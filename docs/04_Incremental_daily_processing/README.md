# 🔄 Incremental Daily Processing

This section documents the automated daily EOD securities pricing
pipeline using **Apache Airflow, AWS S3, and Snowflake**.

The incremental pipeline processes daily market data from the
**Massive API**, stores the generated EOD files in the S3 Bronze layer,
and prepares the data for ingestion into Snowflake.

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

# 🔄 Incremental Pipeline

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
                           CORE
                              │
                       ┌──────┴──────┐
                       ▼             ▼
                     DIM            FACT
                             
```