"""
cortex.py — Snowflake Cortex Analyst integration for the B.A.S.E. Analytics Portal.

Handles:
  1. Auth token extraction from an active Snowpark session (works locally and in SiS)
  2. REST API call to Cortex Analyst with the semantic model passed INLINE
  3. Response parsing: text + SQL + result DataFrame

The semantic model YAML is read from assets/cortex_semantic_model.yaml at
request time and passed directly in the request body — no Snowflake stage required.

API endpoint: POST https://<account>.snowflakecomputing.com/api/v2/cortex/analyst/message

Usage:
    from components.cortex import ask_cortex_analyst, parse_analyst_response
"""

from __future__ import annotations

import contextlib
from pathlib import Path

import pandas as pd
import requests
import streamlit as st
from snowflake.snowpark import Session

# ── Constants ──────────────────────────────────────────────────────────────────
YAML_FILE = "cortex_semantic_model.yaml"
ASSETS_DIR = Path(__file__).parent.parent / "assets"
LOCAL_YAML = ASSETS_DIR / YAML_FILE

CORTEX_API_PATH = "/api/v2/cortex/analyst/message"
REQUEST_TIMEOUT = 90  # Cortex Analyst can take up to ~60s on complex queries


def _load_semantic_model_yaml() -> str:
    """Read the semantic model YAML from the local assets directory."""
    with open(LOCAL_YAML, encoding="utf-8") as f:
        return f.read()


# ── Auth helpers ───────────────────────────────────────────────────────────────


def _get_host_and_token(session: Session) -> tuple[str, str, str]:
    """
    Return (host, token, auth_type) for Cortex API calls.

    Cortex Analyst /api/v2/ requires Authorization: Bearer <JWT>, NOT the
    session token. For local dev we generate a fresh JWT from the private key
    stored in secrets.toml. In SiS the _snowflake module supplies a token
    that must be sent as Snowflake Token (OAuth format).

    Returns:
        host      - e.g. "zcelbqo-hnb09831.snowflakecomputing.com"
        token     - JWT string (local) or OAuth token string (SiS)
        auth_type - "KEYPAIR_JWT" or "OAUTH"
    """
    # ── Path 1: Streamlit in Snowflake ────────────────────────────────────────
    try:
        import _snowflake  # only present inside SiS runtime

        account = st.secrets["connections"]["snowflake"]["account"]
        host = account.lower() + ".snowflakecomputing.com"
        token = _snowflake.get_connection_token()
        return host, token, "OAUTH"
    except (ImportError, ModuleNotFoundError):
        pass

    # ── Path 2: Local dev — generate JWT from private key ────────────────────
    import base64
    import datetime
    import hashlib

    import jwt as pyjwt
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.serialization import load_pem_private_key

    cfg = st.secrets["connections"]["snowflake"]
    account = cfg["account"]  # e.g. "ZCELBQO-HNB09831"
    user = cfg["user"]
    pk_pass = cfg.get("private_key_passphrase", "")

    host = account.lower() + ".snowflakecomputing.com"

    if "private_key" in cfg:
        pem_bytes = cfg["private_key"].encode("utf-8")
    else:
        with open(cfg["private_key_file"], "rb") as f:
            pem_bytes = f.read()

    # Load RSA private key
    private_key = load_pem_private_key(
        pem_bytes,
        password=pk_pass.encode() if pk_pass else None,
    )

    # SHA-256 fingerprint of the PUBLIC key (DER encoded)
    pub_der = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    fingerprint = "SHA256:" + base64.b64encode(hashlib.sha256(pub_der).digest()).decode()

    # JWT payload — Snowflake expects ACCOUNT.USER (uppercase)
    qualified = f"{account.upper()}.{user.upper()}"
    now = datetime.datetime.now(datetime.timezone.utc)
    payload = {
        "iss": f"{qualified}.{fingerprint}",
        "sub": qualified,
        "iat": now,
        "exp": now + datetime.timedelta(minutes=59),
    }

    jwt_token = pyjwt.encode(payload, private_key, algorithm="RS256")
    return host, jwt_token, "KEYPAIR_JWT"


# ── Cortex Analyst API ─────────────────────────────────────────────────────────


def ask_cortex_analyst(
    session: Session,
    question: str,
    conversation_history: list[dict] | None = None,
) -> dict:
    """
    Call the Cortex Analyst REST API with a question and optional conversation history.

    The semantic model YAML is read from the local assets directory and passed
    inline in the request body — no Snowflake stage required.

    Args:
        session: Active Snowpark session
        question: The natural language question
        conversation_history: Previous turns [{"role": "user"|"analyst", "content": [...]}]

    Returns:
        The full API response dict, or a synthetic error dict.
    """
    try:
        host, token, auth_type = _get_host_and_token(session)
    except Exception as exc:
        return {"error": str(exc), "message": None}

    try:
        semantic_model_yaml = _load_semantic_model_yaml()
    except FileNotFoundError:
        return {
            "error": f"Semantic model YAML not found at: {LOCAL_YAML}",
            "message": None,
        }

    # Build messages list
    messages: list[dict] = list(conversation_history or [])
    messages.append(
        {
            "role": "user",
            "content": [{"type": "text", "text": question}],
        }
    )

    payload = {
        "messages": messages,
        "semantic_model": semantic_model_yaml,  # inline — no stage needed
    }

    # Cortex Analyst /api/v2/ uses Bearer JWT for key-pair auth
    # Streamlit-in-Snowflake supplies an OAuth token (Snowflake Token format)
    auth_header = f"Bearer {token}" if auth_type == "KEYPAIR_JWT" else f'Snowflake Token="{token}"'

    try:
        resp = requests.post(
            url=f"https://{host}{CORTEX_API_PATH}",
            json=payload,
            headers={
                "Authorization": auth_header,
                "Content-Type": "application/json",
                "Accept": "application/json",
                "X-Snowflake-Authorization-Token-Type": auth_type,
            },
            timeout=REQUEST_TIMEOUT,
        )
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.Timeout:
        return {
            "error": "Cortex Analyst timed out. Try a simpler question or try again.",
            "message": None,
        }
    except requests.exceptions.HTTPError as exc:
        body = {}
        with contextlib.suppress(Exception):
            body = exc.response.json()
        return {
            "error": f"API error {exc.response.status_code}: {body.get('message', str(exc))}",
            "message": None,
        }
    except requests.exceptions.RequestException as exc:
        return {"error": f"Network error: {exc}", "message": None}


# ── Response parsing ───────────────────────────────────────────────────────────


def parse_analyst_response(response: dict) -> dict:
    """
    Parse a Cortex Analyst API response into structured components.

    Returns:
        {
            "error":    str | None,
            "text":     str | None,     # Cortex's explanation
            "sql":      str | None,     # Generated SQL statement
            "warnings": list[str],
        }
    """
    if "error" in response:
        return {
            "error": response["error"],
            "text": None,
            "sql": None,
            "warnings": [],
        }

    result = {"error": None, "text": None, "sql": None, "warnings": []}

    # Warnings
    result["warnings"] = [w.get("message", str(w)) for w in response.get("warnings", [])]

    # Content blocks from the analyst message
    message = response.get("message", {})
    for block in message.get("content", []):
        block_type = block.get("type")
        if block_type == "text":
            result["text"] = block.get("text", "")
        elif block_type == "sql":
            result["sql"] = block.get("statement", "")

    return result


def execute_analyst_sql(session: Session, sql: str) -> pd.DataFrame | None:
    """Execute a SQL string from Cortex Analyst and return a pandas DataFrame."""
    if not sql:
        return None
    try:
        return session.sql(sql).to_pandas()
    except Exception as exc:
        st.warning(f"Could not execute the generated SQL: {exc}")
        return None


def auto_chart(df: pd.DataFrame, title: str = "") -> bool:
    """
    Try to automatically render an appropriate Plotly chart for a DataFrame.

    Returns True if a chart was rendered, False if it fell back to a table.

    Heuristics:
     - 2 cols, col2 is numeric            → bar chart
     - 3 cols, col2+col3 are numeric      → grouped bar
     - 1 col (scalar result)              → metric card
     - otherwise                          → table
    """
    import plotly.express as px

    from components.styles import PALETTE

    if df is None or df.empty:
        return False

    cols = df.columns.tolist()
    numeric_cols = df.select_dtypes("number").columns.tolist()

    if len(cols) == 1 and len(df) == 1:
        # Single scalar
        col_name = cols[0]
        val = df.iloc[0, 0]
        st.metric(
            col_name.replace("_", " ").title(), f"{val:,}" if isinstance(val, (int, float)) else val
        )
        return True

    if len(cols) >= 2 and len(numeric_cols) >= 1:
        cat_col = cols[0]
        num_col = numeric_cols[0]

        if len(df) <= 30:
            # Horizontal bar for readability with many categories
            fig = px.bar(
                df.sort_values(num_col, ascending=True).tail(20),
                x=num_col,
                y=cat_col,
                orientation="h",
                color_discrete_sequence=[PALETTE["primary"]],
                title=title,
                labels={num_col: num_col.replace("_", " ").title(), cat_col: ""},
            )
            fig.update_traces(marker_line_width=0)
            fig.update_layout(
                height=max(300, min(600, len(df) * 28)), margin=dict(l=160, r=20, t=40, b=20)
            )
            st.plotly_chart(fig, width="stretch")
            return True

    # Fallback: table
    return False
