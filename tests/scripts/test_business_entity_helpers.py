"""
test_business_entity_helpers.py
================================
Unit tests for business_entity_helpers.py.

All external dependencies (requests, boto3, SnowflakeHook) are mocked
so these tests run fully offline — no Snowflake credentials or network
access required. This makes them safe to run in any CI environment.

Run with:
    pytest tests/scripts/test_business_entity_helpers.py -v
"""

from __future__ import annotations

import importlib
import sys
from datetime import timezone
from unittest.mock import MagicMock, call, patch

import pytest

# ── Stub out Airflow before importing the module under test ─────────────────────
# business_entity_helpers imports SnowflakeHook *inside* functions so we only
# need to stub the top-level module so the import doesn't fail outside Airflow.
airflow_stub = MagicMock()
sys.modules.setdefault("airflow", airflow_stub)
sys.modules.setdefault("airflow.providers", airflow_stub)
sys.modules.setdefault("airflow.providers.snowflake", airflow_stub)
sys.modules.setdefault("airflow.providers.snowflake.hooks", airflow_stub)
sys.modules.setdefault("airflow.providers.snowflake.hooks.snowflake", airflow_stub)

import include.eakerian.business_entity_helpers as helpers  # noqa: E402


# ══════════════════════════════════════════════════════════════════════════════
# fetch_business_entity_data
# ══════════════════════════════════════════════════════════════════════════════


class TestFetchBusinessEntityData:
    """Tests for the API ingestion function."""

    @patch("include.eakerian.business_entity_helpers.requests.get")
    def test_returns_records_on_200(self, mock_get):
        """Happy path: API returns a list of records."""
        mock_response = MagicMock()
        mock_response.json.return_value = [
            {"entityid": "1001", "entityname": "Acme Corp", "entitystatus": "Good Standing"},
            {"entityid": "1002", "entityname": "Beta LLC",  "entitystatus": "Good Standing"},
        ]
        mock_response.raise_for_status.return_value = None
        mock_get.return_value = mock_response

        result = helpers.fetch_business_entity_data(date="2024-01-15", api_token="test_token")

        assert len(result) == 2
        assert result[0]["entityid"] == "1001"
        # Verify the URL was constructed correctly
        call_url = mock_get.call_args[0][0]
        assert "2024-01-15T00:00:00.000" in call_url
        assert "test_token" in call_url

    @patch("include.eakerian.business_entity_helpers.requests.get")
    def test_returns_empty_list_when_api_returns_no_records(self, mock_get):
        """API returns an empty list — function must return [] without raising."""
        mock_response = MagicMock()
        mock_response.json.return_value = []
        mock_response.raise_for_status.return_value = None
        mock_get.return_value = mock_response

        result = helpers.fetch_business_entity_data(date="2024-01-15", api_token="test_token")

        assert result == []

    @patch("include.eakerian.business_entity_helpers.requests.get")
    def test_raises_on_network_error(self, mock_get):
        """Network failure must propagate so Airflow can retry the task."""
        import requests as req_lib
        mock_get.side_effect = req_lib.ConnectionError("Connection refused")

        with pytest.raises(req_lib.ConnectionError):
            helpers.fetch_business_entity_data(date="2024-01-15", api_token="test_token")

    @patch("include.eakerian.business_entity_helpers.requests.get")
    def test_raises_on_http_error(self, mock_get):
        """HTTP 4xx/5xx must propagate via raise_for_status."""
        import requests as req_lib
        mock_response = MagicMock()
        mock_response.raise_for_status.side_effect = req_lib.HTTPError("429 Too Many Requests")
        mock_get.return_value = mock_response

        with pytest.raises(req_lib.HTTPError):
            helpers.fetch_business_entity_data(date="2024-01-15", api_token="test_token")


# ══════════════════════════════════════════════════════════════════════════════
# _raw_record_to_tuple
# ══════════════════════════════════════════════════════════════════════════════


class TestRawRecordToTuple:
    """Tests for the field-mapping function."""

    def test_maps_all_known_fields(self):
        """All API field names are mapped to the correct tuple positions."""
        record = {
            "entityid": "9999",
            "entityname": "Test Corp",
            "principaladdress1": "100 Main St",
            "principaladdress2": "Suite 200",
            "principalcity": "Denver",
            "principalstate": "CO",
            "principalzipcode": "80202",
            "principalcountry": "US",
            "entitystatus": "Good Standing",
            "jurisdictonofformation": "Colorado",
            "entitytype": "LLC",
            "entityformdate": "2020-01-01",
        }

        result = helpers._raw_record_to_tuple(record, source_date="2024-01-15")

        assert result[0] == "9999"           # entityid
        assert result[1] == "Test Corp"      # entityname
        assert result[4] == "Denver"         # principalcity
        assert result[8] == "Good Standing"  # entitystatus
        assert result[13] == "2024-01-15"    # _source_date is always last

    def test_missing_optional_fields_default_to_none(self):
        """Missing keys gracefully become None — no KeyError raised."""
        record = {"entityid": "0001", "entityname": "Sparse Corp"}

        result = helpers._raw_record_to_tuple(record, source_date="2024-02-01")

        assert result[0] == "0001"
        assert result[2] is None   # principaladdress1 missing → None
        assert result[13] == "2024-02-01"

    def test_ingested_at_is_utc_datetime(self):
        """The audit timestamp (_ingested_at) must be a UTC-aware datetime."""
        from datetime import datetime

        record = {"entityid": "1"}
        result = helpers._raw_record_to_tuple(record, source_date="2024-01-01")

        ingested_at = result[12]
        assert isinstance(ingested_at, datetime)
        assert ingested_at.tzinfo is not None  # must be timezone-aware


# ══════════════════════════════════════════════════════════════════════════════
# land_raw_records
# ══════════════════════════════════════════════════════════════════════════════


class TestLandRawRecords:
    """Tests for the bronze landing function."""

    def test_skips_when_no_records(self, caplog):
        """Empty record list must short-circuit — no S3 or Snowflake calls."""
        import logging
        with caplog.at_level(logging.INFO):
            helpers.land_raw_records(
                raw_records=[],
                raw_table="DB.SCHEMA.TABLE",
                source_date="2024-01-15",
            )
        assert "skipping" in caplog.text.lower()

    def test_uploads_to_s3_and_calls_copy_into(self):
        """With valid records, must: write parquet → upload S3 → execute COPY INTO."""
        mock_s3_client = MagicMock()
        mock_df = MagicMock()

        mock_boto3 = MagicMock()
        mock_boto3.client.return_value = mock_s3_client

        mock_pd = MagicMock()
        mock_pd.DataFrame.return_value = mock_df

        records = [{"entityid": "1", "entityname": "Corp A"}]

        with patch.dict("sys.modules", {"boto3": mock_boto3, "pandas": mock_pd}), \
             patch("include.eakerian.business_entity_helpers.execute_sf_query") as mock_exec:
            helpers.land_raw_records(
                raw_records=records,
                raw_table="RAW_DEV.PUBLIC.TABLE",
                source_date="2024-01-15",
            )

        mock_df.to_parquet.assert_called_once()
        mock_s3_client.upload_file.assert_called_once()
        mock_exec.assert_called_once()
        sql_arg = mock_exec.call_args[0][0]
        assert "COPY INTO" in sql_arg
        assert "RAW_DEV.PUBLIC.TABLE" in sql_arg


# ══════════════════════════════════════════════════════════════════════════════
# on_dag_failure
# ══════════════════════════════════════════════════════════════════════════════


class TestOnDagFailure:
    """Tests for the failure callback."""

    def test_logs_dag_and_task_ids(self, caplog):
        """The callback must log the dag_id and failed task_id at ERROR level."""
        import logging

        mock_dag = MagicMock()
        mock_dag.dag_id = "business_entity_dag"
        mock_task_instance = MagicMock()
        mock_task_instance.task_id = "fetch_raw"

        context = {
            "dag": mock_dag,
            "run_id": "scheduled__2024-01-15",
            "task_instance": mock_task_instance,
        }

        with caplog.at_level(logging.ERROR):
            helpers.on_dag_failure(context)

        assert "business_entity_dag" in caplog.text
        assert "fetch_raw" in caplog.text
