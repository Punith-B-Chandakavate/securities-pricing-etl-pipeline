# 📥 Massive EOD Data Ingestion — Apache Airflow

![Apache Airflow](https://img.shields.io/badge/Apache%20Airflow-Workflow%20Orchestration-017CEE?logo=apacheairflow\&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.x-3776AB?logo=python\&logoColor=white)
![Massive API](https://img.shields.io/badge/Massive%20API-Market%20Data-blue)
![Ingestion](https://img.shields.io/badge/Pipeline-EOD%20Ingestion-green)

---

## 📖 Overview

This module implements a **batch EOD market-data ingestion workflow using Apache Airflow**.

The DAG connects to the **Massive API**, downloads the latest available trading-day EOD data, stores the response as a local CSV file, and then verifies that the expected file was successfully created.

The workflow is implemented using:

* 🌀 **Apache Airflow** — workflow orchestration
* 🐍 **Python** — ingestion logic
* 📡 **Massive API** — EOD securities data source
* 🔐 **Airflow Variables** — API key and configuration management
* 🔄 **XCom** — passing the trading date between tasks
* 📝 **Logging** — execution and troubleshooting information
* 💾 **CSV** — temporary local ingestion output

---

## 🎯 Learning Objectives

After completing this section, you will understand how to:

* Create an Airflow DAG for batch ingestion
* Schedule an EOD ingestion workflow
* Retrieve configuration using Airflow Variables
* Call reusable Python functions from a DAG
* Download API data into CSV
* Pass values between Airflow tasks using XCom
* Validate that an expected file exists
* Configure retries and retry delays
* Handle task failures using `AirflowFailException`

---

## 🏗️ Project Structure

The Airflow implementation is organized as follows:

```text
airflow/
└── dags/
    ├── lib/
    │   └── eod_data_downloader.py
    │
    └── daily_eod_ingestion_dag.py
```

### 📄 Source Files

| File                                                                          | Purpose                                                                 |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| [`daily_eod_ingestion_dag.py`](../../airflow/dags/daily_eod_ingestion_dag.py) | Defines the Airflow DAG, tasks, schedule, retries and dependencies      |
| [`eod_data_downloader.py`](../../airflow/dags/lib/eod_data_downloader.py)     | Contains the reusable function that downloads Massive EOD data into CSV |

---

# 🔄 Ingestion Workflow

The DAG contains two sequential tasks:

```text
                 Massive API
                     │
                     ▼
          ┌─────────────────────┐
          │ t01_download_to_csv │
          │                     │
          │ Download EOD Data   │
          │ Save as CSV         │
          └──────────┬──────────┘
                     │
                     │ XCom
                     │ trading_date
                     ▼
          ┌─────────────────────┐
          │ t02_verify_local_   │
          │ file                │
          │                     │
          │ Verify CSV exists   │
          └─────────────────────┘
```

The Airflow dependency is:

```python
download >> verify_file
```

Therefore:

```text
t01_download_to_csv
        │
        ▼
t02_verify_local_file
```

---

# ⚙️ DAG Configuration

The DAG is created with:

```python
with DAG(
    'massive_eod_data_download',
    start_date=pendulum.datetime(2026, 9, 1),
    schedule='5 21 * * 1-5',
    catchup=False,
    max_active_runs=1,
    default_args=DEFAULT_ARGS,
    tags=["securities", "batch", "massive"],
    description="Massive-only batch EOD: Download and process the latest available trading day.",
    template_searchpath=TEMPLATE_SEARCHPATH,
):
```

### 📋 Configuration

| Configuration     | Value                            | Purpose                                                |
| ----------------- | -------------------------------- | ------------------------------------------------------ |
| DAG ID            | `massive_eod_data_download`      | Identifies the DAG                                     |
| Start Date        | `2026-09-01`                     | Beginning of DAG scheduling                            |
| Schedule          | `5 21 * * 1-5`                   | Runs Monday–Friday at 21:05 UTC                        |
| `catchup`         | `False`                          | Prevents automatic execution of missed historical runs |
| `max_active_runs` | `1`                              | Allows only one active DAG run                         |
| Tags              | `securities`, `batch`, `massive` | Categorizes the DAG                                    |
| Owner             | `data-eng`                       | DAG owner                                              |

---

# 🔐 Airflow Variables

The DAG retrieves configuration from Airflow Variables rather than hard-coding values directly in the workflow.

```python
POLYGON_API_KEY = Variable.get("MASSIVE_API_KEY")

POLYGON_MAX_LOOKBACK_DAYS = int(
    Variable.get(
        "LOOKBACK_DAYS",
        default_var="10"
    )
)
```

Two variables are used:

```text
MASSIVE_API_KEY
LOOKBACK_DAYS
```

### 🔑 MASSIVE_API_KEY

Stores the API key required to access the Massive API.

### 📅 LOOKBACK_DAYS

Controls the maximum number of days that the downloader can look back when determining the latest available trading day.

The default value is:

```text
10
```

> 🔐 **Security:** API credentials should be stored in Airflow's configuration/secret management rather than directly inside the DAG source code.

---

# 📥 Task 1 — Download EOD Data

Task ID:

```text
t01_download_to_csv
```

The task calls the reusable function:

```python
download_polygon_eod_data_to_csv(
    POLYGON_API_KEY,
    POLYGON_MAX_LOOKBACK_DAYS
)
```

The function is imported from:

```text
airflow/dags/lib/eod_data_downloader.py
```

### 🔄 Task Responsibilities

The task:

1. 🔐 Reads the Massive API key from Airflow Variables
2. 📅 Reads the configured lookback period
3. 📡 Calls the reusable downloader function
4. 📥 Downloads EOD market data
5. 💾 Saves the data as a CSV file
6. 📅 Receives the selected trading date
7. 🔄 Pushes the trading date into XCom
8. 📝 Logs the successful download

---

## 🧩 Download Task

```python
def download_trading_day_csv(**context):

    trading_date = download_polygon_eod_data_to_csv(
        POLYGON_API_KEY,
        POLYGON_MAX_LOOKBACK_DAYS
    )

    context["ti"].xcom_push(
        key="trading_date",
        value=trading_date
    )

    log.info(
        f"Downloaded EOD data for {trading_date}"
    )
```

The Airflow task is created using:

```python
download = PythonOperator(
    task_id="t01_download_to_csv",
    python_callable=download_trading_day_csv,
)
```

---

# 🔄 XCom — Passing the Trading Date

After downloading the data, the task pushes the selected trading date into Airflow XCom:

```python
context["ti"].xcom_push(
    key="trading_date",
    value=trading_date
)
```

The next task retrieves this value:

```python
trading_date = context["ti"].xcom_pull(
    task_ids="t01_download_to_csv",
    key="trading_date"
)
```

The data flow is:

```text
Download Task
     │
     │ trading_date
     ▼
   XCom
     │
     ▼
Verify Task
```

This allows the verification task to construct the expected file path dynamically.

---

# 📂 Task 2 — Verify Local File

Task ID:

```text
t02_verify_local_file
```

The task verifies that the CSV created by the download task actually exists.

The expected file path is constructed using the trading date:

```python
path = f"/tmp/eod_{trading_date}.csv"
```

For example:

```text
/tmp/eod_2026-09-07.csv
```

---

## 🔍 Verification Logic

The task:

1. 🔄 Retrieves `trading_date` from XCom
2. 📂 Builds the expected file path
3. 🔍 Checks whether the file exists
4. 📏 Logs the file size
5. ❌ Fails the task if the file does not exist

```python
if not os.path.exists(path):
    raise AirflowFailException(
        f"Expected file not found: {path}"
    )
```

If the file exists:

```python
log.info(
    "[verify] file exists at %s (size=%s bytes)",
    path,
    os.path.getsize(path)
)
```

---

# 🔗 Task Dependency

The DAG defines the dependency:

```python
download >> verify_file
```

This creates the following execution order:

```text
┌──────────────────────────┐
│ t01_download_to_csv      │
│                          │
│ Download Massive EOD     │
│ data to CSV              │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ t02_verify_local_file    │
│                          │
│ Verify CSV file exists   │
└──────────────────────────┘
```

The verification task will not execute until the download task succeeds.

---

# 🔁 Retry & Failure Handling

The DAG defines default retry settings:

```python
DEFAULT_ARGS = {
    "owner": "data-eng",
    "retries": 3,
    "retry_delay": pendulum.duration(minutes=5),
}
```

Therefore, if a task fails:

```text
Task Failure
     │
     ▼
Wait 5 minutes
     │
     ▼
Retry
     │
     ├── Success → Continue
     │
     └── Failure → Retry again
```

The configured maximum is:

```text
3 retries
```

This is particularly useful for temporary API or network failures.

---

# 📝 Logging

The DAG initializes a Python logger:

```python
log = logging.getLogger(__name__)
```

The workflow records useful execution information such as:

```text
Downloaded EOD data for <trading_date>
```

and:

```text
[verify] expecting file at: <path>
```

and:

```text
[verify] file exists at <path> (size=<bytes>)
```

These logs can be viewed from the Airflow task instance UI.

---

# ⏰ Schedule

The DAG uses:

```text
5 21 * * 1-5
```

This represents:

```text
Minute : 5
Hour   : 21
Days   : Monday–Friday
```

Therefore, the DAG is scheduled for:

```text
21:05 UTC
Monday → Friday
```

The schedule is intended for batch EOD market-data ingestion.

---

# 🚫 Catchup Configuration

The DAG uses:

```python
catchup=False
```

This means Airflow will not automatically execute all historical scheduled intervals that were missed after the DAG's start date.

This is appropriate for this ingestion workflow because the downloader determines the latest available trading day using the configured lookback period.

---

# 🔒 Single Active DAG Run

The DAG uses:

```python
max_active_runs=1
```

This prevents multiple instances of the same DAG from running simultaneously.

```text
DAG Run 1
    │
    ├── Running
    │
    ▼
DAG Run 2
    │
    └── Waits until Run 1 completes
```

This helps avoid overlapping EOD download operations.

---

# 🧱 Reusable Python Library

The API download logic is separated from the DAG:

```text
airflow/
└── dags/
    ├── daily_eod_ingestion_dag.py
    │
    └── lib/
        └── eod_data_downloader.py
```

The DAG imports:

```python
from lib.eod_data_downloader import (
    download_polygon_eod_data_to_csv
)
```

This separation provides a cleaner architecture:

```text
DAG
 │
 │ calls
 ▼
Reusable Downloader
 │
 │ API request
 ▼
Massive API
 │
 │ EOD data
 ▼
CSV File
```

The DAG is responsible for **orchestration**, while the library is responsible for the **data-download implementation**.

---

# 🧪 Manual DAG Testing

After adding or modifying the DAG, restart the Airflow services if required:

```bash
docker compose down
```

Start Airflow again:

```bash
docker compose up -d
```

Open the Airflow UI:

```text
http://localhost:8080
```

Locate:

```text
massive_eod_data_download
```

Then trigger the DAG manually from the Airflow UI.

---

# 🔍 Verify Task Execution

After triggering the DAG, verify:

```text
massive_eod_data_download
        │
        ▼
t01_download_to_csv
        │
        ▼
t02_verify_local_file
```

Both tasks should complete successfully.

Expected result:

```text
t01_download_to_csv       ✅ Success
t02_verify_local_file    ✅ Success
```

---

# 📂 Verify Generated CSV

The verification task expects the downloaded file under:

```text
/tmp/
```

with the naming convention:

```text
eod_<trading_date>.csv
```

Example:

```text
/tmp/eod_2026-09-07.csv
```

The Airflow task log should show the expected path and file size.

---

# 🛠️ Troubleshooting

### ❌ DAG does not appear

Check:

```text
airflow/dags/daily_eod_ingestion_dag.py
```

Then inspect the Airflow scheduler logs.

---

### ❌ API key error

Verify that the Airflow Variable exists:

```text
MASSIVE_API_KEY
```

Also verify that the API key is valid.

---

### ❌ File not found

Check the task logs for:

```text
[verify] expecting file at:
```

Then verify that the downloader created the expected file under:

```text
/tmp/
```

---

### ❌ Download task fails

Check:

* Massive API availability
* API credentials
* Lookback configuration
* Network connectivity
* Airflow task logs

The task is configured with retries to handle temporary failures.

---

# 🛡️ Best Practices

### 🔐 Secure Credentials

Do not hard-code the Massive API key:

```python
POLYGON_API_KEY = "actual-api-key"
```

Instead, use:

```python
Variable.get("MASSIVE_API_KEY")
```

---

### 🧩 Keep DAGs Lightweight

The DAG should primarily orchestrate workflow tasks.

Reusable API/download logic belongs in:

```text
lib/eod_data_downloader.py
```

---

### 🔄 Use Retries

Transient API and network failures can occur.

The DAG uses:

```text
3 retries
5-minute retry delay
```

---

### 📝 Use Meaningful Task IDs

The project uses:

```text
t01_download_to_csv
t02_verify_local_file
```

This makes task execution easier to understand in the Airflow UI.

---

### 🔍 Validate Downloaded Data

Always verify that the expected output file exists before allowing downstream processing.

---

# 📊 Current Pipeline Status

```text
Massive API
     │
     ▼
┌──────────────────────┐
│ Download EOD Data    │
│ t01_download_to_csv  │
└──────────┬───────────┘
           │
           │ CSV
           ▼
       /tmp/eod_*.csv
           │
           ▼
┌──────────────────────┐
│ Verify Local File    │
│ t02_verify_local_file│
└──────────┬───────────┘
           │
           ▼
      File Verified ✅
```

---

# 📁 Related Source Files

| Resource          | Link                                                                          |
| ----------------- | ----------------------------------------------------------------------------- |
| 🌀 Airflow DAG    | [`daily_eod_ingestion_dag.py`](../../airflow/dags/daily_eod_ingestion_dag.py) |
| 🐍 EOD Downloader | [`eod_data_downloader.py`](../../airflow/dags/lib/eod_data_downloader.py)     |

---

# 🎯 Key Takeaways

* 🌀 Airflow orchestrates the EOD ingestion workflow.
* 📡 Massive API provides the market data.
* 🐍 Python handles the API download logic.
* 📂 Downloaded data is stored as a CSV file.
* 🔄 XCom passes the trading date between tasks.
* 🔍 A second task verifies the generated file.
* 🔁 Airflow retries failed tasks automatically.
* 🔐 API credentials are managed using Airflow Variables.
* 🧩 API logic is separated into a reusable Python library.
* ⏰ The DAG runs Monday–Friday at **21:05 UTC**.

---