# ❄️ Snowflake CORE, Dimension & Fact Merge Processing

![Apache Airflow](https://img.shields.io/badge/Apache%20Airflow-EOD%20Data%20Orchestration-017CEE?logo=apacheairflow\&logoColor=white)
![Snowflake](https://img.shields.io/badge/Snowflake-CORE%20Data%20Processing-29B5E8?logo=snowflake\&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-MERGE%20Processing-336791?logo=databricks\&logoColor=white)

> Process validated EOD pricing data from the Snowflake RAW layer into CORE, dimension, and fact tables using sequential SQL merge operations orchestrated by Apache Airflow.

---

## 🎯 Objective

This stage performs the **post-RAW processing** of the End-of-Day securities pricing data.

After the EOD data has been successfully loaded into the Snowflake RAW layer and validated, the pipeline executes a sequence of SQL transformations to populate the downstream data model.

The processing includes:

- 🔄 Merge EOD RAW data into CORE
- 🛡️ Merge security dimension data
- 📅 Build/update the date dimension
- 📊 Merge daily pricing fact data
- 📈 Calculate post-merge metrics

All operations are executed inside the Airflow TaskGroup:

```text
t04_snowflake_load
```

---

# 🏗️ Architecture

```text
                    Snowflake RAW
                         │
                         ▼
                 ┌───────────────┐
                 │   CORE MERGE  │
                 │ 04.merge_core │
                 └───────┬───────┘
                         │
                   ┌─────┴─────┐
                   │           │
                   ▼           ▼
        ┌──────────────────┐  ┌──────────────────┐
        │ Security         │  │ Date             │
        │ Dimension        │  │ Dimension        │
        │ 05.merge_dim_    │  │ 06.merge_dim_    │
        │ security         │  │ date             │
        └────────┬─────────┘  └────────┬─────────┘
                 │                     │
                 └──────────┬──────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │   Daily Price Fact  │
                 │ 07.merge_fact_daily │
                 │       _price        │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │ Post-Merge Metrics  │
                 │ 08.postmerge_metrics│
                 └──────────┬───────────┘
                            │
                            ▼
                     Downstream Data
```

---

# 📂 SQL Source Files

The Snowflake SQL scripts are maintained under:

```text
airflow/
└── dags/
    └── sql/
        ├── 1. copy_to_raw.sql
        ├── 2. check_loaded.sql
        ├── 3. premerge_metrics.sql
        ├── 4. merge_core.sql
        ├── 5. merge_dim_security.sql
        ├── 6. dm_dim_date.sql
        ├── 7. merge_fact_daily_price.sql
        └── 8. postmerge_metrics.sql
```

This README focuses on SQL files **4 through 8**.

---

# 🔄 Processing Workflow

The downstream Snowflake processing follows a dependency-based workflow. After the CORE merge completes, the Security and Date dimensions are processed in parallel before the Daily Price Fact is merged.

```text
RAW Data
   │
   ▼
04. CORE MERGE
   │
   ├──────────────────────┐
   ▼                      ▼
05. SECURITY          06. DATE
    DIMENSION             DIMENSION
   │                      │
   └──────────┬───────────┘
              │
              ▼
       07. DAILY PRICE FACT
              │
              ▼
       08. POST-MERGE METRICS
```

The dependency ensures that each stage completes before the next stage begins.

---

# 1️⃣ Merge RAW Data into CORE

The first operation merges the validated RAW EOD data into the Snowflake CORE layer.

### 📄 SQL File

```text
4. merge_core.sql
```

### Airflow Task

```text
Task ID:
s04_merge_core_eod
```

### Operator

```text
SQLExecuteQueryOperator
```

### Connection

```text
snowflake_default
```

The DAG configuration executes:

```python
merge_core = SQLExecuteQueryOperator(
    task_id="s04_merge_core_eod",
    conn_id="snowflake_default",
    sql="4. merge_core.sql",
    params=params_common,
)
```

### 📌 Processing

```text
RAW EOD Data
      │
      ▼
4. merge_core.sql
      │
      ▼
Snowflake CORE
```

### 📄 Source

[`4. merge_core.sql`](../../airflow/dags/sql/4.%20merge_core.sql)

---

# 2️⃣ Merge Security Dimension

After the CORE processing, the pipeline updates the security dimension.

### 📄 SQL File

```text
5. merge_dim_security.sql
```

### Airflow Task

```text
Task ID:
s05_merge_dim_security
```

### Operator

```text
SQLExecuteQueryOperator
```

### Connection

```text
snowflake_default
```

The DAG executes:

```python
merge_dim_security = SQLExecuteQueryOperator(
    task_id="s05_merge_dim_security",
    conn_id="snowflake_default",
    sql="5. merge_dim_security.sql",
    params=params_common,
)
```

### 📌 Processing

```text
CORE Data
    │
    ▼
5. merge_dim_security.sql
    │
    ▼
Security Dimension
```

This step maintains the security-related dimension data used by downstream pricing analytics.

### 📄 Source

[`5. merge_dim_security.sql`](../../airflow/dags/sql/5.%20merge_dim_security.sql)

---

# 3️⃣ Merge Date Dimension

The next step processes the date dimension.

### 📄 SQL File

```text
6. dm_dim_date.sql
```

### Airflow Task

```text
Task ID:
s06_merge_dim_date
```

### Operator

```text
SQLExecuteQueryOperator
```

### Connection

```text
snowflake_default
```

The DAG configuration is:

```python
merge_dim_date = SQLExecuteQueryOperator(
    task_id="s06_merge_dim_date",
    conn_id="snowflake_default",
    sql="6. dm_dim_date.sql",
    params=params_common,
)
```

### 📌 Processing

```text
CORE / Date Data
       │
       ▼
6. dm_dim_date.sql
       │
       ▼
Date Dimension
```

The date dimension supports date-based analysis of the EOD pricing data.

### 📄 Source

[`6. dm_dim_date.sql`](../../airflow/dags/sql/6.%20dm_dim_date.sql)

---

# 4️⃣ Merge Daily Price Fact

After the required dimensions have been processed, the pipeline merges the daily pricing data into the fact layer.

### 📄 SQL File

```text
7. merge_fact_daily_price.sql
```

### Airflow Task

```text
Task ID:
s07_merge_fact_daily_price
```

### Operator

```text
SQLExecuteQueryOperator
```

### Connection

```text
snowflake_default
```

The DAG executes:

```python
merge_fact = SQLExecuteQueryOperator(
    task_id="s07_merge_fact_daily_price",
    conn_id="snowflake_default",
    sql="7. merge_fact_daily_price.sql",
    params=params_common,
)
```

### 📌 Processing

```text
CORE
 │
 ├── Security Dimension
 │
 └── Date Dimension
          │
          ▼
7. merge_fact_daily_price.sql
          │
          ▼
Daily Price Fact
```

This creates the downstream daily pricing fact data used for EOD securities pricing analytics.

### 📄 Source

[`7. merge_fact_daily_price.sql`](../../airflow/dags/sql/7.%20merge_fact_daily_price.sql)

---

# 5️⃣ Calculate Post-Merge Metrics

The final SQL operation calculates metrics after the CORE, dimension, and fact processing has completed.

### 📄 SQL File

```text
8. postmerge_metrics.sql
```

### Airflow Task

```text
Task ID:
s08_compute_postmerge_metrics
```

### Operator

```text
SQLExecuteQueryOperator
```

### Connection

```text
snowflake_default
```

The DAG configuration is:

```python
postmerge = SQLExecuteQueryOperator(
    task_id="s08_compute_postmerge_metrics",
    conn_id="snowflake_default",
    sql="8. postmerge_metrics.sql",
    params=params_common,
)
```

### 📌 Processing

```text
CORE + Dimensions + Facts
           │
           ▼
8. postmerge_metrics.sql
           │
           ▼
Post-Merge Metrics
```

The metrics provide a final validation/measurement point after the Snowflake merge operations.

### 📄 Source

[`8. postmerge_metrics.sql`](../../airflow/dags/sql/8.%20postmerge_metrics.sql)

---

# 🔗 Snowflake Task Dependencies

The Snowflake processing tasks are executed using the following dependency chain:

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
     ├───────────────┐
     ▼               ▼
merge_dim_security  merge_dim_date
     │               │
     └───────┬───────┘
             ▼
         merge_fact
             │
             ▼
         postmerge
 ```

This ordering ensures that downstream processing operates only after the preceding stage has completed successfully.

---

# 🧩 Airflow TaskGroup

All Snowflake operations belong to:

```text
t04_snowflake_load
```

The TaskGroup contains:

```text
t04_snowflake_load
│
├── s01_copy_to_raw
├── s02_check_eod_prices_exist
├── s03_compute_premerge_metrics
├── s04_merge_core_eod
├── s05_merge_dim_security
├── s06_merge_dim_date
├── s07_merge_fact_daily_price
└── s08_compute_postmerge_metrics
```

The first three tasks handle the RAW loading and pre-merge validation, while tasks **S04–S08** perform the downstream CORE, dimension, fact, and post-merge processing.

---

# 🔄 Complete Snowflake Processing

```text
                S3 Bronze
                    │
                    ▼
             Snowflake Stage
                    │
                    ▼
          ┌──────────────────┐
          │ 01. Copy to RAW  │
          └────────┬─────────┘
                   │
                   ▼
          ┌──────────────────┐
          │ 02. Check Loaded │
          └────────┬─────────┘
                   │
                   ▼
          ┌─────────────────────┐
          │ 03. Pre-Merge       │
          │     Metrics         │
          └─────────┬───────────┘
                    │
                    ▼
          ┌─────────────────────┐
          │ 04. Merge CORE      │
          └─────────┬───────────┘
                    │
              ┌─────┴─────┐
              │           │
              ▼           ▼
     ┌────────────────┐  ┌────────────────┐
     │ 05. Security   │  │ 06. Date       │
     │     Dimension  │  │     Dimension  │
     └───────┬────────┘  └───────┬────────┘
             │                   │
             └─────────┬─────────┘
                       │
                       ▼
             ┌─────────────────────┐
             │ 07. Daily Price     │
             │     Fact            │
             └─────────┬───────────┘
                       │
                       ▼
             ┌─────────────────────┐
             │ 08. Post-Merge      │
             │     Metrics         │
             └─────────┬───────────┘
                       │
                       ▼
                 CORE Analytics
```

---
# 📁 Related Source Files

| Resource | Description | Link |
|---|---|---|
| 🔄 CORE Merge | Merges validated RAW EOD data into CORE | [`4. merge_core.sql`](../../airflow/dags/sql/4.%20merge_core.sql) |
| 🛡️ Security Dimension | Processes security dimension data | [`5. merge_dim_security.sql`](../../airflow/dags/sql/5.%20merge_dim_security.sql) |
| 📅 Date Dimension | Processes the date dimension | [`6. dm_dim_date.sql`](../../airflow/dags/sql/6.%20dm_dim_date.sql) |
| 📈 Daily Price Fact | Processes daily securities pricing fact data | [`7. merge_fact_daily_price.sql`](../../airflow/dags/sql/7.%20merge_fact_daily_price.sql) |
| 📊 Post-Merge Metrics | Calculates metrics after merge processing | [`8. postmerge_metrics.sql`](../../airflow/dags/sql/8.%20postmerge_metrics.sql) |
| 🌀 EOD Ingestion DAG | Orchestrates the complete Snowflake processing workflow | [`daily_eod_ingestion_dag.py`](../../airflow/dags/daily_eod_ingestion_dag.py) |

---

# 🛡️ Best Practices

### 🔐 Use Airflow Connections

Snowflake authentication is handled through the Airflow connection:

```text
snowflake_default
```

Avoid placing credentials directly inside SQL files or DAG source code.

---

### 📄 Keep SQL Logic Separate

The pipeline keeps Snowflake SQL logic in separate files:

```text
sql/
├── 4. merge_core.sql
├── 5. merge_dim_security.sql
├── 6. dm_dim_date.sql
├── 7. merge_fact_daily_price.sql
└── 8. postmerge_metrics.sql
```

This keeps the DAG focused on orchestration while the SQL files contain the database processing logic.

---

### 🔗 Maintain Sequential Dependencies

The processing order is important:

```text
CORE
 │
 ▼
Security Dimension
 │
 ▼
Date Dimension
 │
 ▼
Daily Price Fact
 │
 ▼
Post-Merge Metrics
```

Do not execute downstream fact processing before the required dimension processing has completed.

---

# 📊 Processing Summary

| Step | Task ID | SQL File | Purpose |
|---|---|---|---|
| S04 | `s04_merge_core_eod` | `4. merge_core.sql` | 🔄 Merge RAW data into CORE |
| S05 | `s05_merge_dim_security` | `5. merge_dim_security.sql` | 🛡️ Process security dimension |
| S06 | `s06_merge_dim_date` | `6. dm_dim_date.sql` | 📅 Process date dimension |
| S07 | `s07_merge_fact_daily_price` | `7. merge_fact_daily_price.sql` | 📈 Process daily price fact |
| S08 | `s08_compute_postmerge_metrics` | `8. postmerge_metrics.sql` | 📊 Calculate post-merge metrics |

---

# 💡 Key Takeaways

- ❄️ Snowflake performs the downstream EOD data processing.
- 🔄 RAW data is merged into the CORE layer.
- 🛡️ Security dimension data is processed before fact loading.
- 📅 Date dimension data supports date-based pricing analytics.
- 📈 Daily pricing data is merged into the fact layer.
- 📊 Post-merge metrics provide a final processing checkpoint.
- 🌀 Apache Airflow orchestrates the complete sequence.
- 🔗 All Snowflake tasks use the `snowflake_default` connection.

