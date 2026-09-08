# ☁️ Upload EOD Data to AWS S3

![AWS S3](https://img.shields.io/badge/AWS%20S3-Object%20Storage-FF9900?logo=amazonaws&logoColor=white)
![Apache Airflow](https://img.shields.io/badge/Apache%20Airflow-Orchestration-017CEE?logo=apacheairflow&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.x-3776AB?logo=python&logoColor=white)

---

## 📖 Overview

After the daily EOD pricing data is downloaded from the Massive API
and stored as a local CSV file, the next step is to upload the file
to an Amazon S3 bucket.

Apache Airflow is used to automate this upload as part of the daily
EOD ingestion pipeline.

The uploaded file is stored in the S3 **Bronze layer**, providing a
centralized landing location for downstream Snowflake ingestion.

---

# 🎯 Objective

The objective of this step is to:

- Upload the daily EOD CSV file to Amazon S3.
- Use the Airflow AWS connection to authenticate with AWS.
- Store the file in the Bronze layer.
- Organize files using a structured S3 object path.
- Dynamically generate the file name using the trading date.
- Replace an existing file when the same trading-date file already exists.
- Pass the uploaded data to the next stage of the pipeline.

---

# 🔄 Pipeline Flow

```text
Massive API
     │
     ▼
Download EOD Data
     │
     ▼
Local CSV File
     │
     ▼
Verify File
     │
     ▼
Upload to S3
     │
     ▼
AWS S3
     │
     ▼
market/bronze/eod/
     │
     ▼
Snowflake S3 Stage
````

---

# 📂 Related Source File

The Airflow DAG contains the S3 upload task.

| Resource                   | Link                                                                          |
| -------------------------- | ----------------------------------------------------------------------------- |
| 🌀 Daily EOD Ingestion DAG | [`daily_eod_ingestion_dag.py`](../../airflow/dags/daily_eod_ingestion_dag.py) |
| ☁️ AWS S3 Connection Setup | [`02_aws_s3_airflow_connection.md`](02_aws_s3_airflow_connection.md)          |

---

# 1️⃣ Upload EOD File to S3

The upload is implemented using Airflow's:

```python
LocalFilesystemToS3Operator
```

The operator transfers a local file from the Airflow environment
to an Amazon S3 bucket.

```python
upload_file = LocalFilesystemToS3Operator(
    task_id="t03_upload_to_s3",
    filename="/tmp/eod_{{ ti.xcom_pull(task_ids='t01_download_to_csv', key='trading_date') }}.csv",
    dest_bucket=S3_BUCKET,
    dest_key=(
        "market/bronze/eod/"
        "eod_prices_{{ ti.xcom_pull(task_ids='t01_download_to_csv', key='trading_date') }}.csv"
    ),
    aws_conn_id="aws_default",
    replace=True,
)
```

---

# 2️⃣ Task ID

The task is identified by:

```python
task_id="t03_upload_to_s3"
```

The task ID is used by Airflow to identify and manage the upload
task within the DAG.

The naming convention used in the pipeline is:

```text
t01 → Download
t02 → Verify
t03 → Upload
```

Therefore:

```text
t03_upload_to_s3
```

represents the third step of the daily ingestion workflow.

---

# 3️⃣ Source File

The local CSV file is specified using:

```python
filename="/tmp/eod_{{ ti.xcom_pull(task_ids='t01_download_to_csv', key='trading_date') }}.csv"
```

The file name is dynamically generated using the trading date
returned by the previous task.

---

## 🔗 Using XCom

The trading date is retrieved from the previous task using:

```python
ti.xcom_pull(
    task_ids="t01_download_to_csv",
    key="trading_date"
)
```

### What is XCom?

Airflow XCom allows tasks to exchange small pieces of information.

In this pipeline:

```text
t01_download_to_csv
        │
        │ trading_date
        ▼
      XCom
        │
        ▼
t03_upload_to_s3
```

The upload task uses the trading date produced by the download task
to construct the file name.

---

# 4️⃣ Local File Naming

The local file follows this pattern:

```text
/tmp/eod_<trading_date>.csv
```

For example:

```text
/tmp/eod_2026-09-08.csv
```

This makes it easy to identify the EOD file associated with a
specific trading date.

---

# 5️⃣ S3 Destination Bucket

The destination bucket is defined using:

```python
dest_bucket=S3_BUCKET
```

The bucket name is stored separately rather than hard-coded directly
inside the operator.

This makes the DAG configuration easier to maintain.

---

# 6️⃣ S3 Object Path

The EOD file is uploaded using the following S3 key:

```text
market/bronze/eod/
```

The complete destination path follows this pattern:

```text
market/bronze/eod/eod_prices_<trading_date>.csv
```

For example:

```text
market/bronze/eod/eod_prices_2026-09-08.csv
```

---

# 🥉 Bronze Layer

The S3 destination uses the following structure:

```text
market/
└── bronze/
    └── eod/
        ├── eod_prices_2026-09-05.csv
        ├── eod_prices_2026-09-08.csv
        └── ...
```

The **Bronze layer** acts as the landing area for the daily EOD
pricing files before they are processed by downstream systems.

---

# 7️⃣ AWS Airflow Connection

The upload task uses:

```python
aws_conn_id="aws_default"
```

This tells Airflow to use the configured AWS connection named:

```text
aws_default
```

The connection contains the AWS authentication configuration required
to access the S3 bucket.

The AWS connection was configured in the previous step:

[`02_aws_s3_airflow_connection.md`](02_aws_s3_airflow_connection.md)

---

# 🔐 Authentication Flow

```text
Airflow DAG
     │
     ▼
aws_conn_id="aws_default"
     │
     ▼
Airflow AWS Connection
     │
     ▼
AWS Credentials
     │
     ▼
Amazon S3
```

Credentials should **not** be hard-coded inside the DAG.

Do not place AWS access keys or secret keys directly in Python code.

---

# 8️⃣ Replace Existing Files

The upload task uses:

```python
replace=True
```

This allows the task to replace an existing S3 object when the same
destination key already exists.

For example:

```text
market/bronze/eod/eod_prices_2026-09-08.csv
```

If the file already exists, the new upload can replace it.

This helps prevent stale data from remaining in the S3 Bronze location
when the same trading-date file is reprocessed.

---

# 9️⃣ Task Dependencies

The upload task is executed after the download and file verification
tasks:

```python
download >> verify_file >> upload_file
```

This creates the following dependency chain:

```text
t01_download_to_csv
        │
        ▼
t02_verify_file
        │
        ▼
t03_upload_to_s3
```

---

## Task 1 — Download

```text
t01_download_to_csv
```

Downloads the daily EOD pricing data and creates the local CSV file.

---

## Task 2 — Verify

```text
t02_verify_file
```

Verifies that the expected CSV file exists before attempting the S3
upload.

---

## Task 3 — Upload

```text
t03_upload_to_s3
```

Uploads the verified CSV file from the local Airflow environment to
the S3 Bronze layer.

---

# 🔄 Complete Task Flow

```text
┌───────────────────────────┐
│ t01_download_to_csv       │
│                           │
│ Download EOD data         │
│ Create local CSV          │
│ Push trading_date to XCom │
└─────────────┬─────────────┘
              │
              ▼
┌───────────────────────────┐
│ t02_verify_file           │
│                           │
│ Verify local CSV exists   │
└─────────────┬─────────────┘
              │
              ▼
┌───────────────────────────┐
│ t03_upload_to_s3          │
│                           │
│ LocalFilesystemToS3Operator│
└─────────────┬─────────────┘
              │
              ▼
       ┌───────────────┐
       │   AWS S3      │
       │               │
       │ market/       │
       │ bronze/       │
       │ eod/          │
       └───────────────┘
```

---

# 📁 S3 File Structure

The expected S3 structure is:

```text
S3 Bucket
│
└── market/
    │
    └── bronze/
        │
        └── eod/
            │
            ├── eod_prices_2026-09-05.csv
            ├── eod_prices_2026-09-08.csv
            └── ...
```

Each file represents the EOD pricing data for a specific trading date.

---

# 🧪 Validation

After the Airflow task completes successfully, verify the file in
Amazon S3.

Expected location:

```text
market/bronze/eod/
```

Expected file naming pattern:

```text
eod_prices_<trading_date>.csv
```

Example:

```text
eod_prices_2026-09-08.csv
```

---

# 🔍 Airflow Validation

In the Airflow UI, verify that:

```text
t01_download_to_csv
        ↓
t02_verify_file
        ↓
t03_upload_to_s3
```

are completed successfully.

Expected task state:

```text
SUCCESS
```

---

# ☁️ S3 Validation

Open the configured S3 bucket and navigate to:

```text
market
└── bronze
    └── eod
```

Confirm that the expected EOD CSV file is present.

---

# 📊 Data Flow After S3 Upload

The S3 upload is an intermediate step in the complete daily EOD
pipeline.

```text
Massive API
     │
     ▼
Apache Airflow
     │
     ▼
Download EOD CSV
     │
     ▼
Verify File
     │
     ▼
AWS S3
     │
     ▼
Bronze / EOD
     │
     ▼
Snowflake S3 Stage
     │
     ▼
RAW
     │
     ▼
CORE
     │
     ▼
DIMENSIONS
     │
     ▼
FACT
     │
     ▼
SA / Analytics
     │
     ▼
Power BI
```

---

# 🛡️ Error Prevention

The upload process includes a verification step before the S3
operation:

```text
Download
   ↓
Verify
   ↓
Upload
```

This prevents the pipeline from attempting to upload a file that was
not successfully generated.

The AWS connection is also managed through Airflow rather than
embedding credentials directly in the DAG.
