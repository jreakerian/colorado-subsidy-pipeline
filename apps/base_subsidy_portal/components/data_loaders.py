"""
data_loaders.py — Centralised Snowpark query functions for the B.A.S.E. Analytics Portal.

All Snowflake data access goes through this module. Every function is cached
with st.cache_data to minimise warehouse consumption.

County names in Snowflake are stored lowercase; call .str.title() before
any join to GeoJSON county names (which are Title Case).

Usage:
    from components.data_loaders import get_session, load_crime_density_by_county
"""

from __future__ import annotations

import pandas as pd
import streamlit as st
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, count, lit, upper
from snowflake.snowpark.types import StringType

# ---------------------------------------------------------------------------
# Table / schema constants
# ---------------------------------------------------------------------------

DB = "COLORADO_CRIME_DB_PROD"
GOLD = f"{DB}.GOLD"

FCT_CRIMES = f"{GOLD}.FCT_CRIMES"
FCT_INCOME_POP = f"{GOLD}.FCT_INCOME_POPULATION"
FCT_BUSINESS_TIERS = f"{GOLD}.FCT_BUSINESS_SUBSIDY_TIERS"
DIM_GEOGRAPHY = f"{GOLD}.DIM_GEOGRAPHY"
DIM_OFFENSE = f"{GOLD}.DIM_OFFENSE"
DIM_DATE = f"{GOLD}.DIM_DATE"
DIM_AGENCY = f"{GOLD}.DIM_AGENCY"

RPT_TIER_LOOKUP = f"{GOLD}.RPT_BUSINESS_TIER_LOOKUP"
RPT_AGENCY_BASELINE = f"{GOLD}.RPT_COUNTY_AGENCY_CRIME_BASELINE"
RPT_CITY_TIME_TRENDS = f"{GOLD}.RPT_CITY_TIME_TRENDS"
RPT_CITY_TOD_CRIMES = f"{GOLD}.RPT_CITY_TIME_OF_DAY_CRIMES"
RPT_CITY_DEMOGRAPHICS = f"{GOLD}.RPT_CITY_CRIME_DEMOGRAPHICS"

PUBLIC_COLUMNS = [
    "ENTITY_ID",
    "ENTITY_NAME",
    "PRINCIPAL_CITY",
    "PRINCIPAL_COUNTY",
    "PRINCIPAL_ZIP",
    "ENTITY_TYPE",
    "FORMATION_DATE",
    "ENTITY_STATUS",
    "COMPOSITE_TIER",
    "SUBSIDY_TIER_LABEL",
    "COMPLIANCE_STATUS",
    "QUALIFIES_FOR_SUBSIDY",
    "SUBSIDY_MESSAGE",
]
MAX_NAME_MATCHES = 100


# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------


@st.cache_resource
def get_session() -> Session:
    """
    Build a Snowpark session using RSA key-pair auth.

    Supports two modes:
      1. Streamlit Cloud / SiS: secrets contain `private_key` PEM string
      2. Local dev: secrets contain `private_key_file` path to .pem
    """
    sf = st.secrets["connections"]["snowflake"]

    if "private_key" in sf:
        pem_bytes = sf["private_key"].encode("utf-8")
    elif "private_key_file" in sf:
        with open(sf["private_key_file"], "rb") as f:
            pem_bytes = f.read()
    else:
        raise ValueError(
            "Snowflake RSA auth requires `private_key` or `private_key_file` "
            "in [connections.snowflake] secrets."
        )

    passphrase = sf.get("private_key_passphrase")
    passphrase_bytes = passphrase.encode("utf-8") if passphrase else None

    private_key_obj = serialization.load_pem_private_key(
        pem_bytes, password=passphrase_bytes, backend=default_backend()
    )
    pkcs8_der = private_key_obj.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    return Session.builder.configs(
        {
            "account": sf["account"],
            "user": sf["user"],
            "private_key": pkcs8_der,
            "role": sf.get("role"),
            "warehouse": sf.get("warehouse"),
            "database": sf.get("database"),
            "schema": sf.get("schema"),
        }
    ).create()


# ---------------------------------------------------------------------------
# Landing page — headline stats
# ---------------------------------------------------------------------------


@st.cache_data(ttl="1h", show_spinner=False)
def load_headline_stats(_session: Session) -> dict:
    """4 top-line KPI cards for the landing page."""
    total_crimes = _session.sql(f"SELECT COUNT(*) AS n FROM {FCT_CRIMES}").collect()[0]["N"]

    total_businesses = _session.sql(f"SELECT COUNT(*) AS n FROM {RPT_TIER_LOOKUP}").collect()[0][
        "N"
    ]

    qualifying = _session.sql(
        f"SELECT COUNT(*) AS n FROM {RPT_TIER_LOOKUP} WHERE QUALIFIES_FOR_SUBSIDY = TRUE"
    ).collect()[0]["N"]

    year_range = _session.sql(
        f"SELECT MIN(YEAR(INCIDENT_DATE)) AS y_min, MAX(YEAR(INCIDENT_DATE)) AS y_max FROM {FCT_CRIMES}"
    ).collect()[0]

    return {
        "total_crimes": total_crimes,
        "total_businesses": total_businesses,
        "qualifying_businesses": qualifying,
        "year_min": year_range["Y_MIN"],
        "year_max": year_range["Y_MAX"],
        "years_of_data": year_range["Y_MAX"] - year_range["Y_MIN"] + 1,
        "counties": 64,
    }


# ---------------------------------------------------------------------------
# Act 1 — The Landscape
# ---------------------------------------------------------------------------


@st.cache_data(ttl="1h", show_spinner=False)
def load_crime_density_by_county(_session: Session) -> pd.DataFrame:
    """
    County KPI 7: crimes per 100K residents.
    Returns county_name (title case), fips_code, crime_rate_per_100k, total_crimes.
    """
    df = _session.sql(f"""
        SELECT
            g.county_name,
            COUNT(*) AS total_crimes,
            AVG(ip.total_population) AS avg_population,
            ROUND(COUNT(*) * 100000.0 / NULLIF(AVG(ip.total_population), 0), 1)
                AS crime_rate_per_100k
        FROM {FCT_CRIMES} c
        JOIN {DIM_GEOGRAPHY} g
            ON c.GEO_KEY = g.GEO_KEY AND g.CITY_NAME = '[County Level]'
        JOIN {FCT_INCOME_POP} ip
            ON g.GEO_KEY = ip.GEO_KEY
        GROUP BY g.county_name
        ORDER BY crime_rate_per_100k DESC NULLS LAST
    """).to_pandas()
    df["COUNTY_NAME"] = df["COUNTY_NAME"].str.title()
    return df


@st.cache_data(ttl="1h", show_spinner=False)
def load_crime_categories_by_county(_session: Session) -> pd.DataFrame:
    """
    County KPI 5: top offense categories per county (total crimes by county x category).
    """
    df = _session.sql(f"""
        SELECT
            g.county_name,
            o.offense_category_name,
            o.crime_against,
            COUNT(*) AS total_crimes
        FROM {FCT_CRIMES} c
        JOIN {DIM_GEOGRAPHY} g ON c.GEO_KEY = g.GEO_KEY AND g.CITY_NAME = '[County Level]'
        JOIN {DIM_OFFENSE} o ON c.OFFENSE_KEY = o.OFFENSE_KEY
        GROUP BY g.county_name, o.offense_category_name, o.crime_against
        ORDER BY g.county_name, total_crimes DESC
    """).to_pandas()
    df["COUNTY_NAME"] = df["COUNTY_NAME"].str.title()
    return df


@st.cache_data(ttl="1h", show_spinner=False)
def load_crime_type_distribution_by_county(_session: Session) -> pd.DataFrame:
    """
    County KPI 10: Property / Person / Society share per county.
    """
    df = _session.sql(f"""
        SELECT
            g.county_name,
            o.crime_against,
            COUNT(*) AS total_crimes,
            ROUND(
                COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY g.county_name), 0),
                2
            ) AS pct_of_county_crimes
        FROM {FCT_CRIMES} c
        JOIN {DIM_GEOGRAPHY} g ON c.GEO_KEY = g.GEO_KEY AND g.CITY_NAME = '[County Level]'
        JOIN {DIM_OFFENSE} o ON c.OFFENSE_KEY = o.OFFENSE_KEY
        GROUP BY g.county_name, o.crime_against
        ORDER BY g.county_name, total_crimes DESC
    """).to_pandas()
    df["COUNTY_NAME"] = df["COUNTY_NAME"].str.title()
    return df


# ---------------------------------------------------------------------------
# Act 2 — The Patterns (city marts + county seasonal)
# ---------------------------------------------------------------------------


@st.cache_data(ttl="1h", show_spinner=False)
def load_county_monthly_crimes(_session: Session) -> pd.DataFrame:
    """County KPI 6: total crimes by county x month for the seasonal heatmap."""
    df = _session.sql(f"""
        SELECT
            g.county_name,
            d.month,
            d.month_name,
            d.season,
            COUNT(*) AS total_crimes
        FROM {FCT_CRIMES} c
        JOIN {DIM_GEOGRAPHY} g ON c.GEO_KEY = g.GEO_KEY AND g.CITY_NAME = '[County Level]'
        JOIN {DIM_DATE} d ON c.DATE_KEY = d.DATE_KEY
        GROUP BY g.county_name, d.month, d.month_name, d.season
        ORDER BY g.county_name, d.month
    """).to_pandas()
    df["COUNTY_NAME"] = df["COUNTY_NAME"].str.title()
    return df


@st.cache_data(ttl="1h", show_spinner=False)
def load_city_time_trends(_session: Session) -> pd.DataFrame:
    """City KPIs 1 & 6: from rpt_city_time_trends mart."""
    return _session.table(RPT_CITY_TIME_TRENDS).to_pandas()


@st.cache_data(ttl="1h", show_spinner=False)
def load_city_time_of_day_crimes(_session: Session) -> pd.DataFrame:
    """City KPIs 2 & 4: top 3 day/night crimes from rpt_city_time_of_day_crimes."""
    return _session.table(RPT_CITY_TOD_CRIMES).to_pandas()


@st.cache_data(ttl="1h", show_spinner=False)
def load_city_crime_demographics(_session: Session) -> pd.DataFrame:
    """City KPIs 3 & 5: avg offender age + crime distribution from rpt_city_crime_demographics."""
    return _session.table(RPT_CITY_DEMOGRAPHICS).to_pandas()


# ---------------------------------------------------------------------------
# Act 3 — The Disparity
# ---------------------------------------------------------------------------


@st.cache_data(ttl="1h", show_spinner=False)
def load_income_population_by_county(_session: Session) -> pd.DataFrame:
    """
    County KPIs 2, 3, 4, 8, 9: annual income + population + growth % per county.
    """
    df = _session.sql(f"""
        SELECT
            g.county_name,
            ip.year,
            ip.median_household_income,
            ip.per_capita_income,
            ip.total_population,
            ip.population_growth_pct,
            ip.population_yoy_change
        FROM {FCT_INCOME_POP} ip
        JOIN {DIM_GEOGRAPHY} g ON ip.GEO_KEY = g.GEO_KEY AND g.CITY_NAME = '[County Level]'
        ORDER BY g.county_name, ip.year
    """).to_pandas()
    df["COUNTY_NAME"] = df["COUNTY_NAME"].str.title()
    return df


@st.cache_data(ttl="1h", show_spinner=False)
def load_crime_vs_income(_session: Session) -> pd.DataFrame:
    """
    County KPI 9: crime rate per 100K vs median household income (for scatter plot).
    Aggregated at county level across all years.
    """
    df = _session.sql(f"""
        SELECT
            g.county_name,
            COUNT(*) AS total_crimes,
            AVG(ip.total_population) AS avg_population,
            AVG(ip.median_household_income) AS avg_median_income,
            ROUND(COUNT(*) * 100000.0 / NULLIF(AVG(ip.total_population), 0), 1)
                AS crime_rate_per_100k
        FROM {FCT_CRIMES} c
        JOIN {DIM_GEOGRAPHY} g ON c.GEO_KEY = g.GEO_KEY AND g.CITY_NAME = '[County Level]'
        JOIN {FCT_INCOME_POP} ip ON g.GEO_KEY = ip.GEO_KEY
        GROUP BY g.county_name
        HAVING AVG(ip.median_household_income) IS NOT NULL
        ORDER BY crime_rate_per_100k DESC
    """).to_pandas()
    df["COUNTY_NAME"] = df["COUNTY_NAME"].str.title()
    return df


# ---------------------------------------------------------------------------
# Act 4 — B.A.S.E. Program (business portal)
# ---------------------------------------------------------------------------


@st.cache_data(ttl="15m", show_spinner=False)
def load_tier_breakdown(_session: Session) -> pd.DataFrame:
    """Business count by composite tier."""
    return (
        _session.table(RPT_TIER_LOOKUP)
        .group_by(col("COMPOSITE_TIER"), col("SUBSIDY_TIER_LABEL"))
        .agg(count(lit(1)).alias("BUSINESSES"))
        .sort(col("COMPOSITE_TIER").desc())
        .to_pandas()
    )


@st.cache_data(ttl="15m", show_spinner=False)
def load_eligible_by_county(_session: Session) -> pd.DataFrame:
    """Notification-eligible business counts by county."""
    df = (
        _session.table(RPT_TIER_LOOKUP)
        .filter(col("NOTIFICATION_ELIGIBLE") == lit(True))
        .filter(col("PRINCIPAL_COUNTY").is_not_null())
        .group_by(col("PRINCIPAL_COUNTY"))
        .agg(count(lit(1)).alias("ELIGIBLE_BUSINESSES"))
        .sort(col("ELIGIBLE_BUSINESSES").desc())
        .to_pandas()
    )
    df["PRINCIPAL_COUNTY"] = df["PRINCIPAL_COUNTY"].str.title()
    return df


@st.cache_data(ttl="15m", show_spinner=False)
def load_eligible_total(_session: Session) -> int:
    """Total notification-eligible businesses."""
    return _session.table(RPT_TIER_LOOKUP).filter(col("NOTIFICATION_ELIGIBLE") == lit(True)).count()


def search_businesses(_session: Session, search_term: str) -> pd.DataFrame | None:
    """Search businesses by entity ID or name."""
    term = search_term.strip()
    if not term:
        return None

    base = _session.table(RPT_TIER_LOOKUP).select(*PUBLIC_COLUMNS)

    if term.isdigit():
        id_matches = base.filter(col("ENTITY_ID").cast(StringType()) == lit(term))
        results = id_matches.limit(MAX_NAME_MATCHES + 1).to_pandas()
        if not results.empty:
            return results

    name_matches = (
        base.filter(upper(col("ENTITY_NAME")).like(lit(f"%{term.upper()}%")))
        .sort(col("ENTITY_NAME").asc())
        .limit(MAX_NAME_MATCHES + 1)
    )
    return name_matches.to_pandas()


# ---------------------------------------------------------------------------
# Act 5 — The Impact
# ---------------------------------------------------------------------------


@st.cache_data(ttl="1h", show_spinner=False)
def load_agency_crime_baseline(_session: Session) -> pd.DataFrame:
    """County KPI 1: agency crime baselines + 5% reduction targets."""
    df = _session.table(RPT_AGENCY_BASELINE).to_pandas()
    df["COUNTY_NAME"] = df["COUNTY_NAME"].str.title()
    return df
