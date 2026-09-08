# 🔄 Incremental Daily Processing

This section documents the automated daily EOD securities data
ingestion pipeline using Apache Airflow.

## 📚 Documentation

### 1. Airflow EOD Ingestion

[`01_airflow_eod_ingestion.md`](01_airflow_eod_ingestion.md)

Covers:

- Airflow DAG creation
- Massive API integration
- Airflow Variables
- EOD data download
- XCom
- Local CSV validation
- Retry configuration
- Task dependencies
- DAG scheduling
- Error handling

## 🔄 Pipeline

```text
Massive API
     ↓
Apache Airflow
     ↓
Download EOD Data
     ↓
CSV
     ↓
Verify File