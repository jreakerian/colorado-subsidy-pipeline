"""
business_entity_helpers.py
===========================
All business logic for the Colorado Business Entity ingestion pipeline.

Deliberately decoupled from Airflow primitives so every function here
can be unit-tested in isolation without a running Airflow environment.

Architecture alignment
----------------------
This project uses dbt + Snowflake.  The Airflow DAG (business_entity_dag_v2.py)
is the *ingestion* layer; dbt is the *transformation* layer.

Landing strategy (bronze-first):
  1. API → colorado_business_entities_raw   (RAW_DEV schema — permanent, append-only)
  2. raw → staging table (date-suffixed)    (transformation & enrichment)
  3. staging → production table             (clean, deduplicated, county-enriched)

The raw table sits in the same Snowflake database/schema that dbt's
source('bronze', ...) already points to (SNOWFLAKE_CATALOG / RAW_DEV).

NOTE FOR dbt MAINTAINERS
-------------------------
Add the following entry to dbt_project/models/staging/src_bronze.yml
under the existing 'bronze' source, then create a corresponding staging model:

    - name: colorado_business_entities_raw
      description: >
        Append-only raw API responses from data.colorado.gov.
        Each row represents one business entity returned by the API on a given
        ingestion date. Use _source_date to partition queries by logical date.
        Cast / clean columns in the dbt staging model — never here.

Dependencies
------------
  pip install apache-airflow-providers-snowflake requests
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

import requests

log = logging.getLogger(__name__)


# ── Snowflake helpers ──────────────────────────────────────────────────────────


def execute_sf_query(
    query: str,
    conn_id: str = "snowflake_default",
    parameters: tuple | list | None = None,
    return_results: bool = False,
) -> list:
    """Execute a SQL statement against Snowflake via the Airflow SnowflakeHook.

    Uses the connection configured in Airflow (Admin → Connections → snowflake_default).
    Credentials never touch the DAG file or environment variables directly.

    Args:
        query:          SQL string to execute.
        conn_id:        Airflow Snowflake connection ID.
        parameters:     Optional bind parameters for safe value substitution.
        return_results: When True, fetches and returns all result rows.

    Returns:
        List of row tuples when return_results=True, otherwise [].
    """
    # Import inside function so this module is importable outside Airflow for testing
    from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

    hook = SnowflakeHook(snowflake_conn_id=conn_id)
    conn = hook.get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(query, parameters or ())
            if return_results and cur.description:
                return cur.fetchall()
        conn.commit()
        return []
    finally:
        conn.close()


def execute_sf_many(
    query: str,
    rows: list[tuple],
    conn_id: str = "snowflake_default",
) -> None:
    """Bulk-insert rows using executemany with bind parameters.

    This is the safe alternative to building INSERT statements via string
    interpolation.  Snowflake's Python connector handles quoting and escaping.

    Args:
        query:   INSERT statement with %s placeholders matching the tuple length.
        rows:    List of value tuples — one per row to insert.
        conn_id: Airflow Snowflake connection ID.
    """
    if not rows:
        log.info("execute_sf_many: 0 rows provided — skipping.")
        return

    from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

    hook = SnowflakeHook(snowflake_conn_id=conn_id)
    conn = hook.get_conn()
    try:
        with conn.cursor() as cur:
            cur.executemany(query, rows)
        conn.commit()
        log.info("Bulk-inserted %d rows.", len(rows))
    finally:
        conn.close()


# ── API: data.colorado.gov ─────────────────────────────────────────────────────


def fetch_business_entity_data(date: str, api_token: str) -> list[dict]:
    """Fetch business entity records for a given date from data.colorado.gov.

    Raises on non-200 responses so Airflow can trigger task retries.

    Args:
        date:      Logical execution date string in YYYY-MM-DD format.
        api_token: Socrata app token stored as an Airflow Variable.

    Returns:
        List of raw record dicts exactly as returned by the API.
        Returns [] when the API returns an empty payload.
    """
    log.info("Fetching Colorado business entity records for %s", date)

    formatted_date = f"{date}T00:00:00.000"
    url = (
        f"https://data.colorado.gov/resource/4ykn-tg5h.json"
        f"?$$app_token={api_token}"
        f"&entityformdate={formatted_date}"
        f"&entitystatus=Good%20Standing"
        f"&principalstate=CO"
    )

    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()  # raises HTTPError on 4xx / 5xx
    except requests.RequestException as exc:
        log.error("API request failed for date=%s: %s", date, exc)
        raise  # re-raise so Airflow retries the task

    data = response.json()
    if not data:
        log.info("API returned 0 records for %s", date)
        return []

    log.info("API returned %d records for %s", len(data), date)
    return data


def _raw_record_to_tuple(record: dict, source_date: str) -> tuple:
    """Map one raw API dict to a tuple matching the bronze landing table columns.

    Field order must stay in sync with the INSERT in land_raw_records().
    All values are kept as-is (strings) — no type coercion at the raw layer.
    """
    return (
        record.get("entityid"),
        record.get("entityname"),
        record.get("principaladdress1"),
        record.get("principaladdress2"),
        record.get("principalcity"),
        record.get("principalstate"),
        record.get("principalzipcode"),
        record.get("principalcountry"),
        record.get("entitystatus"),
        record.get("jurisdictonofformation"),
        record.get("entitytype"),
        record.get("entityformdate"),
        datetime.now(timezone.utc),              # _ingested_at: pipeline audit timestamp
        source_date,                    # _source_date: logical execution date (YYYY-MM-DD)
    )


# ── Bronze landing ─────────────────────────────────────────────────────────────


def land_raw_records(
    raw_records: list[dict],
    raw_table: str,
    source_date: str,
    conn_id: str = "snowflake_default",
) -> None:
    """Write raw API records into the append-only bronze landing table.

    This is the ONLY step that calls the external API.  All downstream
    transformation and enrichment steps read from this table, making them
    fully idempotent — re-runnable without re-hitting the API.

    Bronze design principles applied here:
      - No type coercion (entityformdate stays VARCHAR)
      - No filtering beyond what the API already filters
      - Partition metadata (_source_date) appended for efficient pruning
      - Append-only: no UPDATE or DELETE on this table

    Args:
        raw_records: Unmodified list of dicts from fetch_business_entity_data().
        raw_table:   Fully-qualified Snowflake table name.
        source_date: Logical execution date (YYYY-MM-DD) stored as _source_date.
        conn_id:     Airflow Snowflake connection ID.
    """
    if not raw_records:
        log.info("No raw records to land for %s — skipping.", source_date)
        return

    import os

    import boto3
    import pandas as pd

    # Add metadata
    ingested_at = datetime.now(timezone.utc).isoformat()
    for r in raw_records:
        r["_ingested_at"] = ingested_at
        r["_source_date"] = source_date

    # Write to Parquet
    df = pd.DataFrame(raw_records)
    parquet_file = f"/tmp/business_entities_{source_date}.parquet"
    df.to_parquet(parquet_file, index=False)

    # Upload to S3
    s3_bucket = os.getenv("S3_BUCKET_NAME", "colorado-subsidy-lakehouse")
    s3_key = f"raw/colorado_business_entities/source_date={source_date}/data.parquet"
    s3_client = boto3.client("s3")
    s3_client.upload_file(parquet_file, s3_bucket, s3_key)
    log.info("Uploaded to S3: s3://%s/%s", s3_bucket, s3_key)

    # COPY INTO Snowflake
    copy_sql = f"""
        COPY INTO {raw_table}
        FROM @my_ext_stage/{s3_key}
        FILE_FORMAT = (TYPE = PARQUET)
        MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    """
    execute_sf_query(copy_sql, conn_id=conn_id)
    log.info(
        "Landed %d raw records into %s (source_date=%s) via COPY INTO",
        len(raw_records), raw_table, source_date,
    )




# ── Failure alerting ───────────────────────────────────────────────────────────


def on_dag_failure(context: dict) -> None:
    """DAG-level on_failure_callback — replace with your alerting integration.

    Current behaviour: structured log at ERROR level so the message surfaces
    in your log aggregator (CloudWatch, Datadog, etc.) even before you wire
    up a real channel.

    TODO: swap one of the blocks below for your stack:

        # Slack (requires airflow-providers-slack):
        from airflow.providers.slack.hooks.slack_webhook import SlackWebhookHook
        SlackWebhookHook(slack_webhook_conn_id="slack_default").send(
            text=f":red_circle: *DAG FAILED* `{dag_id}` — task `{task_id}` | run `{run_id}`"
        )

        # Email:
        from airflow.utils.email import send_email
        send_email(
            to=["data-team@example.com"],
            subject=f"[Airflow] DAG FAILED: {dag_id}",
            html_content=f"<b>Failed task:</b> {task_id}<br><b>Run:</b> {run_id}",
        )
    """
    dag_id = context.get("dag").dag_id
    run_id = context.get("run_id", "unknown")
    task_instance = context.get("task_instance")
    task_id = task_instance.task_id if task_instance else "unknown"

    log.error(
        "DAG FAILURE | dag_id=%s | run_id=%s | failed_task=%s",
        dag_id,
        run_id,
        task_id,
    )
