"""
business_entity_helpers.py
===========================
All ingestion and failure-handling logic for the Colorado Business Entity pipeline.

Deliberately decoupled from top-level Airflow imports so every function can be
unit-tested in isolation and imported without slowing down DAG parsing.
"""

from __future__ import annotations

import logging
import os
import tempfile
from datetime import UTC, datetime
from pathlib import Path

import requests

log = logging.getLogger(__name__)

SOCRATA_ENDPOINT = "https://data.colorado.gov/resource/4ykn-tg5h.json"
SOCRATA_PAGE_SIZE = 5000  # Socrata SODA 2.1 max limit is 50,000; 5,000 is safe per page


# ── API: data.colorado.gov ─────────────────────────────────────────────────────


def fetch_business_entity_data(date: str, api_token: str) -> list[dict]:
    """Fetch all business entity records for a given date from data.colorado.gov.

    Handles Socrata pagination ($limit / $offset) so busy days exceeding 1,000
    registrations are never silently truncated, and passes the app token via
    HTTP header so secrets never leak into URL logs.
    """
    log.info("Fetching Colorado business entity records for %s", date)

    formatted_date = f"{date}T00:00:00.000"
    headers = {"X-App-Token": api_token} if api_token else {}
    all_records: list[dict] = []
    offset = 0

    with requests.Session() as session:
        session.headers.update(headers)
        while True:
            params = {
                "entityformdate": formatted_date,
                "principalstate": "CO",
                "$limit": SOCRATA_PAGE_SIZE,
                "$offset": offset,
                "$order": "entityid ASC",  # Deterministic ordering for pagination
            }
            try:
                response = session.get(SOCRATA_ENDPOINT, params=params, timeout=30)
                response.raise_for_status()
            except requests.RequestException as exc:
                log.error(
                    "API request failed for date=%s (offset=%d): %s",
                    date,
                    offset,
                    exc,
                )
                raise

            batch = response.json()
            if not batch:
                break

            all_records.extend(batch)
            log.info(
                "Fetched batch of %d records (total so far: %d)",
                len(batch),
                len(all_records),
            )

            # If we received fewer records than the page size, we've reached the last page
            if len(batch) < SOCRATA_PAGE_SIZE:
                break
            offset += SOCRATA_PAGE_SIZE

    log.info("API returned %d total records for %s", len(all_records), date)
    return all_records


# ── Bronze landing (S3 Parquet -> Snowflake External Stage) ────────────────────


def land_raw_records(
    raw_records: list[dict],
    raw_table: str,
    source_date: str,
    conn_id: str = "snowflake_default",
    aws_conn_id: str = "aws_default",
) -> None:
    """Serialize raw API records to Parquet, upload to S3, and idempotently COPY INTO Snowflake.

    Idempotency guarantee:
    - Deletes any existing Bronze records for `source_date` and runs `COPY INTO` with
      `FORCE = TRUE` inside a single Snowflake transaction so retries and backfills
      never duplicate data or get skipped by Snowflake's 64-day load metadata cache.
    """
    if not raw_records:
        log.info("No raw records to land for %s — skipping S3 upload and COPY.", source_date)
        return

    import pandas as pd
    from airflow.providers.amazon.aws.hooks.s3 import S3Hook
    from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

    ingested_at = datetime.now(UTC).isoformat()
    # Build new dicts rather than mutating the input list in-place
    enriched_records = [
        {**record, "_ingested_at": ingested_at, "_source_date": source_date}
        for record in raw_records
    ]

    df = pd.DataFrame(enriched_records)
    s3_bucket = os.getenv("S3_BUCKET_NAME", "colorado-subsidy-pipeline-data-dev")
    s3_key = f"raw/colorado_business_entities/source_date={source_date}/data.parquet"

    # Use a temporary file context manager so worker /tmp storage is always cleaned up
    with tempfile.NamedTemporaryFile(suffix=".parquet", delete=True) as tmp_file:
        parquet_path = Path(tmp_file.name)
        df.to_parquet(parquet_path, index=False)

        s3_hook = S3Hook(aws_conn_id=aws_conn_id)
        s3_hook.load_file(
            filename=parquet_path,
            key=s3_key,
            bucket_name=s3_bucket,
            replace=True,
        )
        log.info("Uploaded Parquet to s3://%s/%s", s3_bucket, s3_key)

    # Atomic Delete + COPY INTO inside a single transaction
    sf_hook = SnowflakeHook(snowflake_conn_id=conn_id)
    with sf_hook.get_conn() as conn, conn.cursor() as cur:
        cur.execute("BEGIN")
        try:
            # 1. Clear partial/previous loads for this logical date
            cur.execute(
                f"DELETE FROM {raw_table} WHERE _source_date = %(source_date)s",
                {"source_date": source_date},
            )
            # 2. Load from S3 with FORCE = TRUE so re-runs aren't ignored by load history
            cur.execute(
                f"""
                COPY INTO {raw_table}
                FROM @"RAW"."RAW_CSV_STAGE"/{s3_key}
                FILE_FORMAT = (TYPE = PARQUET)
                MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
                FORCE = TRUE
                """
            )
            cur.execute("COMMIT")
        except Exception:
            cur.execute("ROLLBACK")
            raise

    log.info(
        "Idempotently landed %d raw records into %s (source_date=%s)",
        len(enriched_records),
        raw_table,
        source_date,
    )


# ── Failure alerting ───────────────────────────────────────────────────────────


def on_dag_failure(context: dict) -> None:
    """Task-level failure callback — logs structured error context for aggregators."""
    dag_obj = context.get("dag")
    dag_id = dag_obj.dag_id if dag_obj else "unknown"
    run_id = context.get("run_id", "unknown")
    ti = context.get("task_instance")
    task_id = ti.task_id if ti else "unknown"
    try_number = ti.try_number if ti else "unknown"
    exception = context.get("exception", "No exception captured")

    log.error(
        "PIPELINE FAILURE | dag_id=%s | task_id=%s | run_id=%s | try=%s | error=%s",
        dag_id,
        task_id,
        run_id,
        try_number,
        exception,
    )
