import os
import logging
import pendulum

from airflow import DAG
from airflow.models import Variable
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.amazon.aws.transfers.local_to_s3 import LocalFilesystemToS3Operator
from airflow.sdk import TaskGroup
from airflow.sdk.exceptions import AirflowFailException
from airflow.providers.snowflake.operators.snowflake import SnowflakeCheckOperator


from lib.eod_data_downloader import download_massive_eod_data_to_csv

# Initialize logger for logging events
log = logging.getLogger(__name__)

# Default arguments for the DAG
DEFAULT_ARGS = {"owner": "data-eng",  # Owner of the DAG
                "retries": 3, # Retry the task 3 times if it fails
                "retry_delay": pendulum.duration(minutes=5),  # Retry delay of 5 minutes
                }
# Setup basic configurations for Polygon API
MASSIVE_API_KEY = Variable.get("MASSIVE_API_KEY")   #API Key for Polygon.io to access market data
MASSIVE_MAX_LOOKBACK_DAYS = int(Variable.get("LOOKBACK_DAYS", default_var="10"))  # Maximum number of days
S3_BUCKET = Variable.get("S3_BUCKET")

TEMPLATE_SEARCHPATH = [os.path.join(os.path.dirname(__file__), "sql")]

with DAG(
    'massive_eod_data_download',
    start_date=pendulum.datetime(2026, 9, 1),  # Start date for the DAG execution
    schedule='5 21 * * 1-5', # Scheduled to run Mon-Fri at 21:05 UTC
    catchup=False,  # Don't backfill past missed runs
    max_active_runs=1,  # Only allow one active DAG run at a time
    default_args=DEFAULT_ARGS,  # Default arguments for task retries and failure handling
    tags=["securities", "batch", "massive"],  # Tags for categorization in the Airflow UI,
    description="Massive-only batch EOD: Download and process the latest available trading day.",
    template_searchpath=TEMPLATE_SEARCHPATH,
):
    # Step 1: Download the trading day's data to CSV (imported from lib)
    def download_trading_day_csv(**context):
        """
        This function downloads the Massive EOD data
        and stores it as a CSV file in the specified location.
        """

        # Use the function from lib/eod_data_downloader.py to download the data for the fixed date
        trading_date = download_massive_eod_data_to_csv(MASSIVE_API_KEY, MASSIVE_MAX_LOOKBACK_DAYS)

        # Push the trading day to XCom for further tasks if needed
        context["ti"].xcom_push(key="trading_date", value=trading_date)

        # Log the success of the task
        log.info(f"Downloaded EOD data for {trading_date}")

    # PythonOperator to call the download function
    download = PythonOperator(
        task_id="t01_download_to_csv",   # Task ID for Airflow UI
        python_callable=download_trading_day_csv,  # Function to execute for this task
    )

    # Step 2: Verify local file
    def verify_file_exists(**context):
        """
        This function checks if the expected CSV file exists at the given local path.
        If not, it raises an AirflowFailException.
        """

        # Get the trading date from XCom (from the previous task)
        trading_date = context["ti"].xcom_pull(task_ids="t01_download_to_csv", key="trading_date")  # Ensure
        path = f"/tmp/eod_{trading_date}.csv"  # Construct the path of the file
        log.info("[verify] expecting file at: %s", path)

        # Check if the file exists locally
        if not os.path.exists(path):
            raise AirflowFailException(f"Expected file not found: {path}")

        # Log the file size if it exists
        log.info("[verify] file exists at %s (size=%s bytes)", path, os.path.getsize(path))

    # PythonOperator to call the Verification function
    verify_file = PythonOperator(
                task_id="t02_verify_local_file",
                python_callable=verify_file_exists)

    # Step 3: Upload to S3
    upload_file = LocalFilesystemToS3Operator(
        task_id="t03_upload_to_s3",
        filename="/tmp/eod_{{ti.xcom_pull(task_ids='t01_download_to_csv', key='trading_date')}}.csv",
        dest_bucket=S3_BUCKET, # S3 bucket where the file will be uploaded
        dest_key=(
            "market/bronze/eod/"
            "eod_prices_{{ ti.xcom_pull(task_ids='t01_download_to_csv', key='trading_date') }}.csv"
        ),
        aws_conn_id="aws_default",  # AWS connection ID to fetch credentials
        replace=True,  # Replace the file if it already exists in S3
    )

    # Step 4: Snowflake load
    with TaskGroup(group_id="t04_snowflake_load") as snowflake_load:

        params_common = {
            "trading_ds_task_id": "t01_download_to_csv"
        }

        # S01: Load EOD CSV from S3 into RAW
        copy_to_raw = SQLExecuteQueryOperator(
            task_id="s01_copy_to_raw",
            conn_id="snowflake_default",
            sql="1. copy_to_raw.sql",
            params=params_common,
        )

        # S02: Verify that the EOD data was successfully loaded
        check_loaded = SnowflakeCheckOperator(
            task_id="s02_check_eod_prices_exist",
            sql="2. check_loaded.sql",
            snowflake_conn_id="snowflake_default",
            params=params_common,
        )

        # S03: Calculate metrics before RAW → CORE merge
        premerge_metrics = SQLExecuteQueryOperator(
            task_id="s03_compute_premerge_metrics",
            conn_id="snowflake_default",
            sql="3. premerge_metrics.sql",
            params=params_common,
        )

        # Snowflake task dependencies
        copy_to_raw >> check_loaded >> premerge_metrics


    # Overall pipeline dependency
    download >> verify_file >> upload_file >> snowflake_load
