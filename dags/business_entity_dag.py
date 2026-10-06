from __future__ import annotations

# ── Standard library ──────────────────────────────────────────────────────────
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

from airflow.sdk import dag, task

# ── Cosmos (dbt) ──────────────────────────────────────────────────────────────
from cosmos import DbtTaskGroup, ExecutionConfig, ProfileConfig, ProjectConfig
from cosmos.profiles import SnowflakeEncryptedPrivateKeyFilePemProfileMapping

# ── Project helpers ───────────────────────────────────────────────────────────
from include.eakerian.business_entity_helpers import on_dag_failure

SNOWFLAKE_CONN_ID = "snowflake_default"
RAW_TABLE = os.environ.get("PIPELINE_RAW_TABLE", "RAW.colorado_business_entities_raw")

PROD_TABLE = os.environ.get("PIPELINE_PROD_TABLE", "RAW.colorado_business_entities")

SCHEMA = os.environ.get("PIPELINE_SCHEMA", "RAW")

DBT_TARGET = os.environ.get("PIPELINE_DBT_TARGET", "dev")

_AIRFLOW_HOME = os.environ.get("AIRFLOW_HOME", "/usr/local/airflow")
_SQL_DIR = Path(_AIRFLOW_HOME) / "include" / "sql"

# ──────────────────────────────────────────────────────────────────────────────
# Retry configuration
#
# Defined once so the DAG default and the fetch task override are explicit
# and not accidentally diverged by a copy-paste.
# ──────────────────────────────────────────────────────────────────────────────
_DEFAULT_RETRY_ARGS: dict = {
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

_FETCH_RETRY_ARGS: dict = {
    # External API calls warrant one extra retry; everything else uses the
    # DAG default above.
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
}

# ──────────────────────────────────────────────────────────────────────────────
# dbt / Cosmos config
#
# Constructed at module scope so the scheduler does not re-instantiate these
# objects on every DAG heartbeat.
# ──────────────────────────────────────────────────────────────────────────────
_profile_config = ProfileConfig(
    profile_name="colorado_subsidy_pipeline",
    target_name=DBT_TARGET,
    profile_mapping=SnowflakeEncryptedPrivateKeyFilePemProfileMapping(
        conn_id=SNOWFLAKE_CONN_ID,
        profile_args={
            "schema": SCHEMA,
            # dbt needs TRANSFORMER_ROLE to create schemas, views, and tables
            # across Silver and Gold layers. LOADER_ROLE is restricted to RAW
            # ingestion only and must not be used for transformations.
            "role": "TRANSFORMER_ROLE",
        },
    ),
)

_execution_config = ExecutionConfig(
    dbt_executable_path=f"{_AIRFLOW_HOME}/dbt_venv/bin/dbt",
)


# ──────────────────────────────────────────────────────────────────────────────
# Task-level failure callback
#
# The DAG-level on_failure_callback fires when the DAG run fails, but it does
# not tell you which task failed without clicking into the UI.  This wrapper
# adds the task_id to the alert so on-call engineers know immediately where to
# look.
# ──────────────────────────────────────────────────────────────────────────────
def on_task_failure(context: dict) -> None:
    """Enrich the DAG-level failure callback with the failing task's id."""
    ti = context.get("task_instance")
    if ti:
        context["task_failure_details"] = (
            f"Task '{ti.task_id}' failed in DAG '{ti.dag_id}' (run_id: {ti.run_id})"
        )
    on_dag_failure(context)


# ──────────────────────────────────────────────────────────────────────────────
# DAG
# ──────────────────────────────────────────────────────────────────────────────
@dag(
    dag_id="business_entity_dag",
    description=(
        "Fetches daily Colorado business entity records from data.colorado.gov, "
        "lands raw strings in the Snowflake bronze layer, deduplicates by entityid "
        "into the production source table, then hands off to dbt for all "
        "transformation, filtering, and enrichment."
    ),
    default_args={
        "owner": "eakerian",
        "on_failure_callback": on_task_failure,  # task-level alert with task_id
        "execution_timeout": timedelta(hours=1),
        **_DEFAULT_RETRY_ARGS,
    },
    start_date=datetime(2026, 10, 4, tzinfo=timezone.utc),
    max_active_runs=1,
    schedule="0 13 * * *",  # 1 PM UTC ≈ 7 AM MT
    catchup=False,
    tags=["eakerian", "capstone"],
    on_failure_callback=on_dag_failure,  # DAG-run-level alert
)
def business_entity_dag():
    # ── Task 1: Fetch from API → land raw strings into bronze ─────────────
    @task(
        task_id="fetch_and_land_raw",
        **_FETCH_RETRY_ARGS,
    )
    def fetch_and_land_raw(yesterday: str) -> None:
        """Call the Colorado SoS API and write raw, untransformed records to bronze.

        Design decisions
        ────────────────
        - `yesterday` is injected via {{ ds }} (logical_date as YYYY-MM-DD).

        """
        from airflow.sdk import Variable

        from include.eakerian.business_entity_helpers import (
            fetch_business_entity_data,
            land_raw_records,
        )

        api_token = Variable.get("DATA_COLORADO_GOV_KEY")
        raw_records = fetch_business_entity_data(date=yesterday, api_token=api_token)
        land_raw_records(
            raw_records=raw_records,
            raw_table=RAW_TABLE,
            source_date=yesterday,
            conn_id=SNOWFLAKE_CONN_ID,
        )

    # ── Task 2: Assert rows actually landed before continuing ─────────────
    @task(task_id="assert_rows_landed")
    def assert_rows_landed(yesterday: str) -> None:
        """Fail fast if the API returned nothing for the target date.

        Without this gate, a 0-row response from the API would allow the MERGE
        and the entire dbt run to succeed silently — giving the false impression
        that the pipeline is healthy while a day's data is missing.

        Raises
        ──────
        ValueError
            When no rows for `yesterday` exist in the raw bronze table.
        """
        from include.eakerian.business_entity_helpers import execute_sf_query

        result = execute_sf_query(
            f"SELECT COUNT(*) AS cnt FROM {RAW_TABLE} WHERE _source_date = '{yesterday}'",
            conn_id=SNOWFLAKE_CONN_ID,
            return_results=True,
        )
        # execute_sf_query is assumed to return a list of tuples like [(0,)]
        row_count = (
            result[0][0]
            if isinstance(result, (list, tuple)) and isinstance(result[0], (list, tuple))
            else result
        )
        if row_count == 0:
            raise ValueError(
                f"Zero rows landed in {RAW_TABLE} for _source_date = '{yesterday}'. "
                "The API may have returned an empty response or the load failed. "
                "Halting pipeline to avoid a silent data gap."
            )

    # ── Task 3: Dedup MERGE — raw strings only, zero transformation ───────
    @task(task_id="merge_new_to_production")
    def merge_new_to_production(yesterday: str) -> None:
        """Idempotently write net-new entityids from bronze into production."""

        from include.eakerian.business_entity_helpers import execute_sf_query

        sql_template = (_SQL_DIR / "merge_new_to_production.sql").read_text()
        sql = sql_template.format(
            raw_table=RAW_TABLE,
            prod_table=PROD_TABLE,
            yesterday=yesterday,
        )
        execute_sf_query(sql, conn_id=SNOWFLAKE_CONN_ID)

    # ── Task 4: dbt

    trigger_dbt = DbtTaskGroup(
        group_id="trigger_dbt_run",
        project_config=ProjectConfig(f"{_AIRFLOW_HOME}/include/dbt/dbt_project"),
        profile_config=_profile_config,
        execution_config=_execution_config,
        operator_args={
            "select": "stg_colorado_business_entities+",
        },
    )

    # ── Dependency chain ──────────────────────────────────────────────────
    # {{ ds }} = the logical date formatted as YYYY-MM-DD.
    # On scheduled runs, Airflow automatically sets this to yesterday (the start
    # of the previous data interval), so the API always receives yesterday's date.
    # On backfills, this becomes whichever historical date is being replayed.
    # For manual triggers, use "Trigger DAG w/ config" and set the logical date
    # to yesterday manually to avoid a zero-row API response.
    yesterday = "{{ ds }}"

    (
        fetch_and_land_raw(yesterday=yesterday)
        >> assert_rows_landed(yesterday=yesterday)
        >> merge_new_to_production(yesterday=yesterday)
        >> trigger_dbt
    )


business_entity_dag()
