# 🔄 Incremental Daily Processing

This section documents the automated daily EOD securities pricing
pipeline using Apache Airflow, AWS S3, and Snowflake.

## 📚 Documentation

### 1. Airflow EOD Ingestion

[`01_airflow_eod_ingestion.md`](01_airflow_eod_ingestion.md)

Covers:

- Airflow DAG
- Massive API
- EOD data download
- Airflow Variables
- XCom
- Task dependencies
- Retry handling
- Local CSV validation

### 2. AWS S3 & Airflow Connection

[`02_aws_s3_airflow_connection.md`](02_aws_s3_airflow_connection.md)

Covers:

- AWS S3 bucket
- IAM user
- S3 permissions
- AWS access keys
- Airflow AWS connection
- `aws_default`
- S3 connectivity

## 🔄 Incremental Pipeline

```text
Massive API
     ↓
Apache Airflow
     ↓
Download EOD CSV
     ↓
Amazon S3
     ↓
Snowflake
     ↓
RAW → CORE → DIM → FACT