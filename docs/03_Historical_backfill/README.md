# 📥 Historical Data Backfill

This section documents the complete historical data backfill process.

## 📚 Documentation

### 1. Historical RAW Data Backfill

[`01_raw_data_backfill.md`](01_raw_data_backfill.md)

Covers:

- Historical CSV generation
- Snowflake Add Data
- Database/schema selection
- RAW table loading
- RAW data validation

### 2. Data Transformation

[`02_data_transformation.md`](02_data_transformation.md)

Covers:

- RAW → CORE
- Data cleansing
- Deduplication
- Security Dimension
- Date Dimension
- Daily Pricing Fact
- Data validation

## 🔄 Overall Flow

```text
Massive API
     ↓
Historical CSV
     ↓
RAW
     ↓
CORE
     ↓
DIMENSIONS
     ↓
FACT