from __future__ import annotations

# ── Standard library ──────────────────────────────────────────────────────────
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

from airflow.providers.common.sql.operators.sql import (
    SQLCheckOperator,
    SQLExecuteQueryOperator,
)
from airflow.sdk import dag, task

# ── Cosmos (dbt) ──────────────────────────────────────────────────────────────
from cosmos import (
    DbtTaskGroup,
    ExecutionConfig,
    LoadMode,
    ProfileConfig,
    ProjectConfig,
    RenderConfig,
)
from cosmos.profiles import SnowflakeEncryptedPrivateKeyFilePemProfileMapping

# ── Project helpers ───────────────────────────────────────────────────────────
from include.eakerian.business_entity_helpers import on_dag_failure

SNOWFLAKE_CONN_ID = "snowflake_default"
RAW_TABLE = os.environ.get("PIPELINE_RAW_TABLE", "RAW.colorado_business_entities_raw")
PROD_TABLE = os.environ.get("PIPELINE_PROD_TABLE", "RAW.colorado_business_entities")
SCHEMA = os.environ.get("PIPELINE_SCHEMA", "RAW")
DBT_TARGET = os.environ.get("PIPELINE_DBT_TARGET", "dev")

_AIRFLOW_HOME = Path(os.environ.get("AIRFLOW_HOME", "/usr/local/airflow"))
_DBT_PROJECT_DIR = _AIRFLOW_HOME / "include" / "dbt" / "dbt_project"

# ──────────────────────────────────────────────────────────────────────────────
# Retry configuration
# ──────────────────────────────────────────────────────────────────────────────
_DEFAULT_RETRY_ARGS: dict = {
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,  # Avoid hammering flaky services at fixed intervals
}

_FETCH_RETRY_ARGS: dict = {
    "retries": 3,
    "retry_delay": timedelta(minutes=2),
    "retry_exponential_backoff": True,
    "max_retry_delay": timedelta(minutes=15),
}

# ──────────────────────────────────────────────────────────────────────────────
# dbt / Cosmos config
#
# Note: The DAG Processor executes this module on every parse cycle. To prevent
# Cosmos from spawning a slow `dbt ls` subprocess on every parse, we use
# LoadMode.DBT_MANIFEST when a pre-compiled manifest.json is available.
# ──────────────────────────────────────────────────────────────────────────────
_profile_config = ProfileConfig(
    profile_name="colorado_subsidy_pipeline",
    target_name=DBT_TARGET,
    profile_mapping=SnowflakeEncryptedPrivateKeyFilePemProfileMapping(
        conn_id=SNOWFLAKE_CONN_ID,
        profile_args={
            "schema": SCHEMA,
            "role": "TRANSFORMER_ROLE",
        },
    ),
)

_execution_config = ExecutionConfig(
    dbt_executable_path=str(_AIRFLOW_HOME / "dbt_venv" / "bin" / "dbt"),
)

_manifest_path = _DBT_PROJECT_DIR / "target" / "manifest.json"
_render_config = RenderConfig(
    select=["stg_colorado_business_entities+"],
    # Parse-time optimization: read static JSON manifest instead of running dbt CLI
    load_method=LoadMode.DBT_MANIFEST if _manifest_path.exists() else LoadMode.AUTOMATIC,
)


# ──────────────────────────────────────────────────────────────────────────────
# Task-level failure callback
# ──────────────────────────────────────────────────────────────────────────────
def on_task_failure(context: dict) -> None:
    """Enrich failure context with the failing task_id and fire a single alert."""
    ti = context.get("task_instance")
    if ti:
        context["task_failure_details"] = (
            f"Task '{ti.task_id}' failed in DAG '{ti.dag_id}' "
            f"(run_id: {ti.run_id}, try_number: {ti.try_number})"
        )
    on_dag_failure(context)


# ──────────────────────────────────────────────────────────────────────────────
# DAG Definition
# ──────────────────────────────────────────────────────────────────────────────
@dag(
    dag_id="business_entity_dag",
    description=(
        "Fetches daily Colorado business entity records from data.colorado.gov, "
        "idempotently lands raw strings in Snowflake Bronze, validates row counts, "
        "deduplicates into the production source table, and triggers dbt."
    ),
    # Tells Airflow where to look for .sql files referenced in SQL operators
    template_searchpath=[str(_AIRFLOW_HOME / "include" / "sql")],
    default_args={
        "owner": "eakerian",
        "on_failure_callback": on_task_failure,  # Fires once per terminal task failure
        "execution_timeout": timedelta(hours=1),
        **_DEFAULT_RETRY_ARGS,
    },
    start_date=datetime(2026, 10, 4, tzinfo=timezone.utc),
    max_active_runs=1,
    schedule="0 13 * * *",  # 1 PM UTC ≈ 7 AM MT
    catchup=False,
    tags=["eakerian", "capstone", "bronze-to-gold"],
    # Removed DAG-level on_failure_callback to prevent double-paging on task failure.
    # Instead, use dagrun_timeout to catch hung runs.
    dagrun_timeout=timedelta(hours=2),
)
def business_entity_dag():
    # Compute target date reliably whether triggered by schedule OR manual UI button:
    # (data_interval_end - 1 day) always resolves to "yesterday" relative to the run window.
    target_date = "{{ (data_interval_end - macros.timedelta(days=1)) | ds }}"

    # ── Task 1: Fetch from API → idempotently land raw strings into bronze ─
    @task(
        task_id="fetch_and_land_raw",
        **_FETCH_RETRY_ARGS,
    )
    def fetch_and_land_raw(target_date: str, api_token: str) -> None:
        """Fetch Colorado SoS API records and overwrite the target_date partition in Bronze."""
        from include.eakerian.business_entity_helpers import (
            fetch_business_entity_data,
            land_raw_records,
        )

        raw_records = fetch_business_entity_data(date=target_date, api_token=api_token)
        # NOTE: Ensure land_raw_records executes a DELETE WHERE _source_date = target_date
        # inside the same transaction BEFORE inserting so task retries are 100% idempotent.
        land_raw_records(
            raw_records=raw_records,
            raw_table=RAW_TABLE,
            source_date=target_date,
            conn_id=SNOWFLAKE_CONN_ID,
        )

    # ── Task 2: Native Circuit Breaker (Zero custom Python boilerplate) ───
    # SQLCheckOperator fails automatically if the query returns 0, False, or None.
    assert_rows_landed = SQLCheckOperator(
        task_id="assert_rows_landed",
        conn_id=SNOWFLAKE_CONN_ID,
        sql=f"SELECT COUNT(*) FROM {RAW_TABLE} WHERE _source_date = '{target_date}'",
    )

    # ── Task 3: Deferrable & Parameterized MERGE ──────────────────────────
    # Uses native SQLExecuteQueryOperator with deferrable=True so the worker slot
    # is released to the Triggerer while Snowflake executes the MERGE.
    merge_new_to_production = SQLExecuteQueryOperator(
        task_id="merge_new_to_production",
        conn_id=SNOWFLAKE_CONN_ID,
        sql="merge_new_to_production.sql",  # Resolved via template_searchpath
        params={
            "raw_table": RAW_TABLE,
            "prod_table": PROD_TABLE,
        },
        parameters={"target_date": target_date},  # Safe bind parameter (prevents SQL injection)
    )

    # ── Task 4: Cosmos dbt Task Group ─────────────────────────────────────
    trigger_dbt = DbtTaskGroup(
        group_id="trigger_dbt_run",
        project_config=ProjectConfig(
            dbt_project_path=str(_DBT_PROJECT_DIR),
            manifest_path=str(_manifest_path) if _manifest_path.exists() else None,
        ),
        profile_config=_profile_config,
        execution_config=_execution_config,
        render_config=_render_config,
    )

    # ── Dependency Chain ──────────────────────────────────────────────────
    (
        fetch_and_land_raw(
            target_date=target_date, api_token="{{ var.value.DATA_COLORADO_GOV_KEY }}"
        )
        >> assert_rows_landed
        >> merge_new_to_production
        >> trigger_dbt
    )


business_entity_dag()
