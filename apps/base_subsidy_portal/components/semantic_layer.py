"""
semantic_layer.py — Metric catalog and saved query definitions for the B.A.S.E.
Semantic Layer Showcase (Page 7).

These definitions are parsed from the dbt MetricFlow YAML files:
  - include/dbt/dbt_project/models/marts/facts/schema.yml
  - include/dbt/dbt_project/models/marts/facts/_cross_model_metrics.yml
  - include/dbt/dbt_project/models/marts/facts/_saved_queries.yml

No live dbt parsing — values are static so the page loads instantly.
The Snowpark queries that back the "Live Results" section use the physical
Gold layer tables directly (same data, no MetricFlow runtime needed).
"""

from __future__ import annotations

import pandas as pd
import streamlit as st
from snowflake.snowpark import Session

# ── Metric catalog ─────────────────────────────────────────────────────────────

METRICS: list[dict] = [
    # ── fct_crimes ────────────────────────────────────────────────────────────
    {
        "name":         "total_crimes",
        "label":        "Total Crimes",
        "type":         "simple",
        "aggregation":  "SUM",
        "source_model": "fct_crimes",
        "expression":   "crime_count",
        "kpis":         "C1 C5 C6 C7 Ci1 Ci2 Ci4 Ci6",
        "description":  "Crime incident count. Slice by any geo/offense/agency/date combination.",
    },
    {
        "name":         "crime_avg_age",
        "label":        "Crime Avg Age",
        "type":         "simple",
        "aggregation":  "AVG",
        "source_model": "fct_crimes",
        "expression":   "age_num",
        "kpis":         "Ci3",
        "description":  "Average recorded age of individuals involved (~47% null; nulls ignored by AVG).",
    },
    # ── fct_income_population ─────────────────────────────────────────────────
    {
        "name":         "avg_median_household_income",
        "label":        "Avg Median Household Income",
        "type":         "simple",
        "aggregation":  "AVG",
        "source_model": "fct_income_population",
        "expression":   "median_household_income",
        "kpis":         "C2 C9",
        "description":  "Median household income averaged across years in scope.",
    },
    {
        "name":         "avg_per_capita_income",
        "label":        "Avg Per Capita Income",
        "type":         "simple",
        "aggregation":  "AVG",
        "source_model": "fct_income_population",
        "expression":   "per_capita_income",
        "kpis":         "C8",
        "description":  "Per capita income averaged across years in scope.",
    },
    {
        "name":         "avg_total_personal_income",
        "label":        "Avg Total Personal Income",
        "type":         "simple",
        "aggregation":  "AVG",
        "source_model": "fct_income_population",
        "expression":   "total_personal_income",
        "kpis":         "—",
        "description":  "Total personal income (county-level aggregate) averaged across years.",
    },
    {
        "name":         "avg_total_population",
        "label":        "Avg Total Population",
        "type":         "simple",
        "aggregation":  "AVG",
        "source_model": "fct_income_population",
        "expression":   "total_population",
        "kpis":         "C3 C7",
        "description":  "Population is a point-in-time snapshot — always averaged, never summed.",
    },
    {
        "name":         "avg_population_yoy_change",
        "label":        "Avg Population YoY Change",
        "type":         "simple",
        "aggregation":  "AVG",
        "source_model": "fct_income_population",
        "expression":   "population_yoy_change",
        "kpis":         "C3",
        "description":  "Year-over-year absolute change in county population.",
    },
    {
        "name":         "avg_population_growth_pct",
        "label":        "Avg Population Growth %",
        "type":         "simple",
        "aggregation":  "AVG",
        "source_model": "fct_income_population",
        "expression":   "population_growth_pct",
        "kpis":         "C4",
        "description":  "Year-over-year population growth % — feeds the >10% anomaly KPI.",
    },
    {
        "name":         "counties_exceeding_10pct_growth_years",
        "label":        "County-Years Exceeding 10% Growth",
        "type":         "simple",
        "aggregation":  "SUM",
        "source_model": "fct_income_population",
        "expression":   "CASE WHEN population_growth_pct > 10 THEN 1 ELSE 0 END",
        "kpis":         "C4",
        "description":  "Count of county-year rows where population growth exceeded 10%.",
    },
    # ── fct_business_subsidy_tiers ────────────────────────────────────────────
    {
        "name":         "business_count",
        "label":        "Business Count",
        "type":         "simple",
        "aggregation":  "COUNT",
        "source_model": "fct_business_subsidy_tiers",
        "expression":   "business_key",
        "kpis":         "Ci5",
        "description":  "Count of Colorado businesses with an assigned B.A.S.E. tier.",
    },
    {
        "name":         "avg_business_composite_tier",
        "label":        "Avg Business Composite Tier",
        "type":         "simple",
        "aggregation":  "AVG",
        "source_model": "fct_business_subsidy_tiers",
        "expression":   "composite_tier",
        "kpis":         "—",
        "description":  "Average composite tier (1–4) across businesses in scope.",
    },
    {
        "name":         "subsidy_qualifying_business_count",
        "label":        "Subsidy-Qualifying Business Count",
        "type":         "simple",
        "aggregation":  "SUM (boolean)",
        "source_model": "fct_business_subsidy_tiers",
        "expression":   "qualifies_for_subsidy",
        "kpis":         "—",
        "description":  "Count of businesses that qualify for a B.A.S.E. subsidy (composite_tier ≥ 3).",
    },
    {
        "name":         "notification_eligible_business_count",
        "label":        "Notification-Eligible Business Count",
        "type":         "simple",
        "aggregation":  "SUM (boolean)",
        "source_model": "fct_business_subsidy_tiers",
        "expression":   "notification_eligible",
        "kpis":         "—",
        "description":  "Count of businesses eligible for automated OEDIT notification.",
    },
    # ── Cross-model (derived) ─────────────────────────────────────────────────
    {
        "name":         "crime_to_population_ratio",
        "label":        "Crime-to-Population Ratio",
        "type":         "ratio",
        "aggregation":  "total_crimes ÷ avg_total_population",
        "source_model": "fct_crimes + fct_income_population",
        "expression":   "total_crimes / avg_total_population",
        "kpis":         "C3 C7 C9",
        "description":  "Cross-model ratio: joins fct_crimes and fct_income_population via shared geo entity.",
    },
    {
        "name":         "crime_rate_per_100k",
        "label":        "Crime Rate per 100k Residents",
        "type":         "derived",
        "aggregation":  "crime_to_population_ratio × 100,000",
        "source_model": "fct_crimes + fct_income_population",
        "expression":   "crime_to_population_ratio * 100000",
        "kpis":         "C3 C7 C9",
        "description":  "Human-readable crime rate. Replaces three hand-computed columns in the old rpt_* layer.",
    },
]

# ── Saved queries ──────────────────────────────────────────────────────────────

SAVED_QUERIES: list[dict] = [
    {
        "name":        "county_crime_rate_annual",
        "label":       "County Crime Rate — Annual",
        "description": "Annual crime count by county — the most common BI query against fct_crimes.",
        "metrics":     ["total_crimes"],
        "group_by":    ["TimeDimension('metric_time', 'year')", "Dimension('geo__county_name')"],
        "mf_command":  "mf query --metrics total_crimes --group-by metric_time__year,geo__county_name",
        "sql": """
SELECT
    g.county_name,
    YEAR(f.incident_date) AS year,
    SUM(f.crime_count)    AS total_crimes
FROM COLORADO_CRIME_DB_PROD.GOLD.FCT_CRIMES f
JOIN COLORADO_CRIME_DB_PROD.GOLD.DIM_GEOGRAPHY g ON f.geo_key = g.geo_key
WHERE g.city_name = '[County Level]'
GROUP BY g.county_name, YEAR(f.incident_date)
ORDER BY total_crimes DESC
LIMIT 20""".strip(),
    },
    {
        "name":        "subsidy_eligibility_by_county",
        "label":       "Subsidy Eligibility — by County",
        "description": "Subsidy-qualifying business count by county — OEDIT's primary outreach metric.",
        "metrics":     ["subsidy_qualifying_business_count", "business_count"],
        "group_by":    ["Dimension('business__principal_county')"],
        "mf_command":  "mf query --metrics subsidy_qualifying_business_count,business_count --group-by business__principal_county",
        "sql": """
SELECT
    principal_county,
    COUNT(*)                                                         AS total_businesses,
    SUM(CASE WHEN qualifies_for_subsidy THEN 1 ELSE 0 END)           AS qualifying_businesses,
    ROUND(100.0 * SUM(CASE WHEN qualifies_for_subsidy THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_qualifying
FROM COLORADO_CRIME_DB_PROD.GOLD.FCT_BUSINESS_SUBSIDY_TIERS
GROUP BY principal_county
ORDER BY qualifying_businesses DESC
LIMIT 20""".strip(),
    },
    {
        "name":        "income_population_by_county_annual",
        "label":       "Income & Population — Annual by County",
        "description": "Annual median household income and population by county — socioeconomic trend query.",
        "metrics":     ["avg_median_household_income", "avg_total_population"],
        "group_by":    ["TimeDimension('metric_time', 'year')", "Dimension('geo__county_name')"],
        "mf_command":  "mf query --metrics avg_median_household_income,avg_total_population --group-by metric_time__year,geo__county_name",
        "sql": """
SELECT
    g.county_name,
    f.year,
    ROUND(AVG(f.median_household_income), 0) AS avg_median_household_income,
    ROUND(AVG(f.total_population), 0)        AS avg_total_population
FROM COLORADO_CRIME_DB_PROD.GOLD.FCT_INCOME_POPULATION f
JOIN COLORADO_CRIME_DB_PROD.GOLD.DIM_GEOGRAPHY g ON f.geo_key = g.geo_key
GROUP BY g.county_name, f.year
ORDER BY f.year DESC, avg_median_household_income DESC
LIMIT 20""".strip(),
    },
]

# ── Metric catalog as DataFrame ────────────────────────────────────────────────

def get_metric_catalog_df() -> pd.DataFrame:
    """Return the metric catalog as a display-ready DataFrame."""
    rows = []
    for m in METRICS:
        rows.append({
            "Metric":       m["label"],
            "Type":         m["type"].capitalize(),
            "Aggregation":  m["aggregation"],
            "Source Model": m["source_model"],
            "KPIs":         m["kpis"],
            "Description":  m["description"],
        })
    return pd.DataFrame(rows)


# ── Live query runners ─────────────────────────────────────────────────────────

@st.cache_data(ttl=3600, show_spinner=False)
def run_saved_query(_session: Session, name: str) -> pd.DataFrame:
    """Execute a saved query's equivalent SQL via Snowpark and return the results."""
    sq = next((q for q in SAVED_QUERIES if q["name"] == name), None)
    if sq is None:
        return pd.DataFrame()
    try:
        return _session.sql(sq["sql"]).to_pandas()
    except Exception as exc:
        st.warning(f"Query failed: {exc}")
        return pd.DataFrame()


@st.cache_data(ttl=3600, show_spinner=False)
def run_crime_rate_spotlight(_session: Session) -> pd.DataFrame:
    """Run the cross-model crime_rate_per_100k metric for the top 15 counties.

    Uses RPT_COUNTY_AGENCY_CRIME_BASELINE (processed crime totals from the
    Gold reporting layer) joined to FCT_INCOME_POPULATION (raw population fact).
    Note: FCT_CRIMES has NIBRS administrative records — multiple rows per
    physical incident — so we use the pre-aggregated reporting mart here for
    accurate counts. This mirrors how MetricFlow would resolve a ratio metric
    between a measure on a reporting model and avg_total_population.
    """
    sql = """
        WITH crime_totals AS (
            SELECT
                LOWER(county_name)      AS county_name,
                SUM(total_crimes)       AS total_crimes
            FROM COLORADO_CRIME_DB_PROD.GOLD.RPT_COUNTY_AGENCY_CRIME_BASELINE
            GROUP BY LOWER(county_name)
        ),
        pop_avg AS (
            SELECT g.county_name, AVG(ip.total_population) AS avg_population
            FROM COLORADO_CRIME_DB_PROD.GOLD.FCT_INCOME_POPULATION ip
            JOIN COLORADO_CRIME_DB_PROD.GOLD.DIM_GEOGRAPHY          g ON ip.geo_key = g.geo_key
            WHERE g.city_name = '[County Level]'
            GROUP BY g.county_name
        )
        SELECT
            INITCAP(c.county_name)                                                     AS county_name,
            c.total_crimes,
            ROUND(p.avg_population, 0)                                                 AS avg_population,
            ROUND(c.total_crimes * 100000.0 / NULLIF(p.avg_population, 0), 1)         AS crime_rate_per_100k
        FROM crime_totals c
        JOIN pop_avg      p ON c.county_name = p.county_name
        ORDER BY crime_rate_per_100k DESC
        LIMIT 15
    """
    try:
        return _session.sql(sql).to_pandas()
    except Exception as exc:
        st.warning(f"Spotlight query failed: {exc}")
        return pd.DataFrame()
