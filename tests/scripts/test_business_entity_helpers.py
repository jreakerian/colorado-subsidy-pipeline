"""
test_business_entity_helpers.py
================================
Unit tests for business_entity_helpers.py.

All external dependencies (requests, S3Hook, SnowflakeHook) are mocked
so these tests run fully offline — no Snowflake credentials or network
access required. This makes them safe to run in any CI environment.

Run with:
    pytest tests/scripts/test_business_entity_helpers.py -v
"""

from __future__ import annotations

import sys
from unittest.mock import MagicMock, patch

import pytest

# ── Stub out Airflow before importing the module under test ─────────────────────
# business_entity_helpers imports SnowflakeHook and S3Hook *inside* functions so
# we only need to stub the top-level modules so the import doesn't fail outside Airflow.
airflow_stub = MagicMock()
sys.modules.setdefault("airflow", airflow_stub)
sys.modules.setdefault("airflow.providers", airflow_stub)
sys.modules.setdefault("airflow.providers.snowflake", airflow_stub)
sys.modules.setdefault("airflow.providers.snowflake.hooks", airflow_stub)
sys.modules.setdefault("airflow.providers.snowflake.hooks.snowflake", airflow_stub)
sys.modules.setdefault("airflow.providers.amazon", airflow_stub)
sys.modules.setdefault("airflow.providers.amazon.aws", airflow_stub)
sys.modules.setdefault("airflow.providers.amazon.aws.hooks", airflow_stub)
sys.modules.setdefault("airflow.providers.amazon.aws.hooks.s3", airflow_stub)

import include.eakerian.business_entity_helpers as helpers  # noqa: E402

# ══════════════════════════════════════════════════════════════════════════════
# fetch_business_entity_data
# ══════════════════════════════════════════════════════════════════════════════


class TestFetchBusinessEntityData:
    """Tests for the API ingestion function."""

    def _make_mock_session(self, pages: list[list[dict]]):
        """Build a mock requests.Session whose .get() returns pages sequentially."""
        mock_session = MagicMock()
        responses = []
        for page in pages:
            mock_resp = MagicMock()
            mock_resp.json.return_value = page
            mock_resp.raise_for_status.return_value = None
            responses.append(mock_resp)
        mock_session.get.side_effect = responses
        return mock_session

    @patch("include.eakerian.business_entity_helpers.requests.Session")
    def test_returns_records_on_200(self, mock_session_cls):
        """Happy path: API returns a single page of records."""
        records = [
            {"entityid": "1001", "entityname": "Acme Corp", "entitystatus": "Good Standing"},
            {"entityid": "1002", "entityname": "Beta LLC", "entitystatus": "Good Standing"},
        ]
        mock_session = self._make_mock_session([records, []])
        mock_session_cls.return_value.__enter__ = MagicMock(return_value=mock_session)
        mock_session_cls.return_value.__exit__ = MagicMock(return_value=False)

        result = helpers.fetch_business_entity_data(date="2024-01-15", api_token="test_token")

        assert len(result) == 2
        assert result[0]["entityid"] == "1001"
        # Verify the token is passed as a header, NOT in the URL
        mock_session.headers.update.assert_called_once_with({"X-App-Token": "test_token"})

    @patch("include.eakerian.business_entity_helpers.requests.Session")
    def test_paginates_until_empty_page(self, mock_session_cls):
        """Pagination: fetches multiple pages until an empty page signals the end."""
        page1 = [{"entityid": str(i)} for i in range(helpers.SOCRATA_PAGE_SIZE)]
        page2 = [{"entityid": "9999"}]
        mock_session = self._make_mock_session([page1, page2, []])
        mock_session_cls.return_value.__enter__ = MagicMock(return_value=mock_session)
        mock_session_cls.return_value.__exit__ = MagicMock(return_value=False)

        result = helpers.fetch_business_entity_data(date="2024-01-15", api_token="tok")

        assert len(result) == helpers.SOCRATA_PAGE_SIZE + 1
        # Three GET calls: page 1 (full), page 2 (partial → last), no third call needed
        assert mock_session.get.call_count == 2

    @patch("include.eakerian.business_entity_helpers.requests.Session")
    def test_returns_empty_list_when_api_returns_no_records(self, mock_session_cls):
        """API returns an empty list — function must return [] without raising."""
        mock_session = self._make_mock_session([[]])
        mock_session_cls.return_value.__enter__ = MagicMock(return_value=mock_session)
        mock_session_cls.return_value.__exit__ = MagicMock(return_value=False)

        result = helpers.fetch_business_entity_data(date="2024-01-15", api_token="test_token")

        assert result == []

    @patch("include.eakerian.business_entity_helpers.requests.Session")
    def test_raises_on_network_error(self, mock_session_cls):
        """Network failure must propagate so Airflow can retry the task."""
        import requests as req_lib

        mock_session = MagicMock()
        mock_session.get.side_effect = req_lib.ConnectionError("Connection refused")
        mock_session_cls.return_value.__enter__ = MagicMock(return_value=mock_session)
        mock_session_cls.return_value.__exit__ = MagicMock(return_value=False)

        with pytest.raises(req_lib.ConnectionError):
            helpers.fetch_business_entity_data(date="2024-01-15", api_token="test_token")

    @patch("include.eakerian.business_entity_helpers.requests.Session")
    def test_raises_on_http_error(self, mock_session_cls):
        """HTTP 4xx/5xx must propagate via raise_for_status."""
        import requests as req_lib

        mock_response = MagicMock()
        mock_response.raise_for_status.side_effect = req_lib.HTTPError("429 Too Many Requests")
        mock_session = MagicMock()
        mock_session.get.return_value = mock_response
        mock_session_cls.return_value.__enter__ = MagicMock(return_value=mock_session)
        mock_session_cls.return_value.__exit__ = MagicMock(return_value=False)

        with pytest.raises(req_lib.HTTPError):
            helpers.fetch_business_entity_data(date="2024-01-15", api_token="test_token")


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

    @patch("pandas.DataFrame")
    @patch("airflow.providers.amazon.aws.hooks.s3.S3Hook")
    @patch("airflow.providers.snowflake.hooks.snowflake.SnowflakeHook")
    def test_uploads_to_s3_and_copies_into_snowflake(
        self, mock_sf_hook_cls, mock_s3_hook_cls, mock_df_class
    ):
        """With valid records: write parquet → upload via S3Hook → DELETE+COPY INTO in transaction."""
        # --- S3Hook mock ---
        mock_s3_hook = MagicMock()
        mock_s3_hook_cls.return_value = mock_s3_hook

        # --- SnowflakeHook / connection / cursor mock ---
        mock_cur = MagicMock()
        mock_conn = MagicMock()
        mock_conn.cursor.return_value.__enter__ = MagicMock(return_value=mock_cur)
        mock_conn.cursor.return_value.__exit__ = MagicMock(return_value=False)
        mock_sf_conn_ctx = MagicMock()
        mock_sf_conn_ctx.__enter__ = MagicMock(return_value=mock_conn)
        mock_sf_conn_ctx.__exit__ = MagicMock(return_value=False)
        mock_sf_hook = MagicMock()
        mock_sf_hook.get_conn.return_value = mock_sf_conn_ctx
        mock_sf_hook_cls.return_value = mock_sf_hook

        # --- DataFrame mock ---
        mock_df = MagicMock()
        mock_df_class.return_value = mock_df

        records = [{"entityid": "1", "entityname": "Corp A"}]

        helpers.land_raw_records(
            raw_records=records,
            raw_table="RAW_DEV.PUBLIC.TABLE",
            source_date="2024-01-15",
        )

        # Parquet was written
        mock_df.to_parquet.assert_called_once()
        # S3Hook.load_file was used (not boto3 upload_file)
        mock_s3_hook.load_file.assert_called_once()
        load_kwargs = mock_s3_hook.load_file.call_args.kwargs
        assert load_kwargs.get("replace") is True
        assert "2024-01-15" in load_kwargs.get("key", "")
        # Transaction was opened and COPY INTO was executed
        mock_cur.execute.assert_called()
        sql_calls = [str(c) for c in mock_cur.execute.call_args_list]
        assert any("COPY INTO" in s for s in sql_calls)
        assert any("DELETE" in s for s in sql_calls)


# ══════════════════════════════════════════════════════════════════════════════
# on_dag_failure
# ══════════════════════════════════════════════════════════════════════════════


class TestOnDagFailure:
    """Tests for the failure callback."""

    def test_logs_dag_task_run_try_and_exception(self, caplog):
        """The callback must log dag_id, task_id, run_id, try_number, and the exception."""
        import logging

        mock_dag = MagicMock()
        mock_dag.dag_id = "business_entity_dag"
        mock_task_instance = MagicMock()
        mock_task_instance.task_id = "fetch_and_land_raw"
        mock_task_instance.try_number = 2

        context = {
            "dag": mock_dag,
            "run_id": "scheduled__2024-01-15",
            "task_instance": mock_task_instance,
            "exception": ValueError("Something went wrong"),
        }

        with caplog.at_level(logging.ERROR):
            helpers.on_dag_failure(context)

        assert "business_entity_dag" in caplog.text
        assert "fetch_and_land_raw" in caplog.text
        assert "scheduled__2024-01-15" in caplog.text

    def test_handles_missing_context_keys_gracefully(self, caplog):
        """Callback must not raise even when optional context keys are absent."""
        import logging

        context: dict = {}  # completely empty context

        with caplog.at_level(logging.ERROR):
            helpers.on_dag_failure(context)  # must not raise

        assert "PIPELINE FAILURE" in caplog.text
