"""
Page 7 — 🔮 The Semantic Layer

Showcase of the dbt MetricFlow semantic layer that underpins the entire
B.A.S.E. Analytics Portal.

Sections:
  1. Metric Catalog   — all 15 metrics defined across 3 semantic models
  2. Architecture     — Mermaid diagram: dbt → Snowflake → Cortex Analyst
  3. Spotlight        — crime_rate_per_100k cross-model derived metric
  4. Saved Queries    — the 3 MetricFlow saved queries with live results
"""

import plotly.express as px
import streamlit as st
from components.data_loaders import get_session
from components.semantic_layer import (
    METRICS,
    SAVED_QUERIES,
    get_metric_catalog_df,
    run_crime_rate_spotlight,
    run_saved_query,
)
from components.styles import PALETTE, inject_css

# ── Page config ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Semantic Layer · B.A.S.E. Portal",
    page_icon="🔮",
    layout="wide",
)
inject_css()
session = get_session()

# ── Header ─────────────────────────────────────────────────────────────────────
st.markdown(
    '<div class="act-badge">dbt MetricFlow · Snowflake Semantic Layer</div>',
    unsafe_allow_html=True,
)
st.title("🔮 The Semantic Layer")
st.markdown(
    "Every number in this portal originates from a **version-controlled semantic model** "
    "defined in dbt MetricFlow. This page exposes the architecture: how raw incidents "
    "become governed metrics, and how those metrics power both human dashboards and "
    "Snowflake Cortex AI."
)

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# Section 1 — Metric Catalog
# ══════════════════════════════════════════════════════════════════════════════
st.subheader("📋 Metric Catalog")
st.caption(
    "15 metrics defined across 3 dbt semantic models. "
    "Filtered by type, model, or KPI tag using the controls below."
)

col_f1, col_f2, col_f3 = st.columns(3)
with col_f1:
    type_filter = st.multiselect(
        "Metric type",
        options=["Simple", "Ratio", "Derived"],
        default=[],
        placeholder="All types",
        key="catalog_type_filter",
    )
with col_f2:
    model_filter = st.multiselect(
        "Source model",
        options=sorted({m["source_model"] for m in METRICS}),
        default=[],
        placeholder="All models",
        key="catalog_model_filter",
    )
with col_f3:
    kpi_search = st.text_input(
        "Filter by KPI tag (e.g. C7, Ci3)",
        value="",
        placeholder="C7",
        key="catalog_kpi_search",
    )

df_catalog = get_metric_catalog_df()
if type_filter:
    df_catalog = df_catalog[df_catalog["Type"].isin(type_filter)]
if model_filter:
    df_catalog = df_catalog[df_catalog["Source Model"].isin(model_filter)]
if kpi_search.strip():
    df_catalog = df_catalog[df_catalog["KPIs"].str.contains(kpi_search.strip(), case=False)]

# Colour rows by metric type
TYPE_COLORS = {
    "Simple": PALETTE["bg_border"],
    "Ratio": "#2d3561",
    "Derived": "#3d1e6b",
}

st.dataframe(
    df_catalog.reset_index(drop=True),
    width="stretch",
    hide_index=True,
    height=min(600, 55 + len(df_catalog) * 38),
    column_config={
        "Metric": st.column_config.TextColumn("Metric", width="medium"),
        "Type": st.column_config.TextColumn("Type", width="small"),
        "Aggregation": st.column_config.TextColumn("Aggregation", width="medium"),
        "Source Model": st.column_config.TextColumn("Source Model", width="medium"),
        "KPIs": st.column_config.TextColumn("KPIs", width="small"),
        "Description": st.column_config.TextColumn("Description", width="large"),
    },
)

# Metric type breakdown mini-chart
type_counts = get_metric_catalog_df()["Type"].value_counts().reset_index()
type_counts.columns = ["Type", "Count"]
fig_types = px.bar(
    type_counts,
    x="Count",
    y="Type",
    orientation="h",
    color="Type",
    color_discrete_map={
        "Simple": PALETTE["primary"],
        "Ratio": "#7b68ee",
        "Derived": "#c471ed",
    },
    text="Count",
    title="Metrics by Type",
)
fig_types.update_traces(textposition="outside", marker_line_width=0)
fig_types.update_layout(
    height=200,
    showlegend=False,
    margin=dict(l=80, r=40, t=40, b=20),
    xaxis=dict(showgrid=False, visible=False),
)
st.plotly_chart(fig_types, width="stretch")

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# Section 2 — Architecture Diagram
# ══════════════════════════════════════════════════════════════════════════════
st.subheader("🏗️ Architecture")
st.caption(
    "How raw crime incidents flow through dbt MetricFlow into governed Snowflake objects "
    "and power both human analytics and Cortex AI."
)

st.markdown(
    """
```mermaid
graph TD
    subgraph Sources["📥 Raw Sources"]
        S1["CDPS Crime Incidents\n(9M rows, 1997-2024)"]
        S2["BEA Income & Population\n(county x year)"]
        S3["CDOS Business Registry\n(3.1M businesses)"]
    end

    subgraph dbt["⚙️ dbt-core Project"]
        direction TB
        SM1["Semantic Model\nfct_crimes\n• total_crimes\n• crime_avg_age"]
        SM2["Semantic Model\nfct_income_population\n• avg_median_household_income\n• avg_total_population\n• avg_population_growth_pct\n• +4 more"]
        SM3["Semantic Model\nfct_business_subsidy_tiers\n• business_count\n• subsidy_qualifying_business_count\n• +2 more"]
        CM["Cross-Model Metrics\n_cross_model_metrics.yml\n• crime_to_population_ratio\n• crime_rate_per_100k ★"]
        SQ["Saved Queries\n_saved_queries.yml\n• county_crime_rate_annual\n• subsidy_eligibility_by_county\n• income_population_by_county_annual"]
    end

    subgraph Snowflake["❄️ Snowflake Gold Layer"]
        GF1["FCT_CRIMES"]
        GF2["FCT_INCOME_POPULATION"]
        GF3["FCT_BUSINESS_SUBSIDY_TIERS"]
        RPTS["Reporting Marts\nRPT_CITY_TIME_TRENDS\nRPT_BUSINESS_TIER_LOOKUP\n+3 more"]
    end

    subgraph Apps["🖥️ Applications"]
        ST["Streamlit Portal\nPages 1-5: Data Narrative\nPage 6: Cortex Analyst Chat\nPage 7: Semantic Layer"]
        CA["Cortex Analyst\ncortex_semantic_model.yaml\n(grounded on Gold marts)"]
    end

    S1 --> GF1 --> SM1
    S2 --> GF2 --> SM2
    S3 --> GF3 --> SM3
    SM1 & SM2 --> CM
    SM1 & SM2 & SM3 --> SQ
    GF1 & GF2 & GF3 --> RPTS --> ST
    CM --> CA
    CA --> ST

    style CM fill:#7b2d8b,stroke:#333,color:#fff
    style CA fill:#0072c6,stroke:#333,color:#fff
    style ST fill:#1a6640,stroke:#333,color:#fff
```
""",
    unsafe_allow_html=False,
)

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# Section 3 — Cross-Model Metric Spotlight: crime_rate_per_100k
# ══════════════════════════════════════════════════════════════════════════════
st.subheader("⭐ Cross-Model Metric Spotlight: `crime_rate_per_100k`")
st.markdown(
    """
This is the most technically interesting metric in the project. It is a **derived metric**
that depends on a **ratio metric** that itself joins **two separate fact tables**
via a shared `geo` entity — something that was previously computed three different ways
in three separate hand-crafted SQL models.

**The chain:**
```
crime_rate_per_100k  (derived)
  └── crime_to_population_ratio  (ratio)
        ├── numerator:   total_crimes        → fct_crimes.crime_count
        └── denominator: avg_total_population → fct_income_population.total_population
              joined on: geo entity (dim_geography.geo_key)
```

**Why this matters:** MetricFlow resolves the join at query time — no pre-joined table,
no denormalization, no drift between three copies of the same formula.
"""
)

tab_yaml, tab_sql, tab_chart = st.tabs(
    ["📄 YAML Definition", "🔍 Equivalent SQL", "📊 Live Results"]
)

with tab_yaml:
    st.code(
        """
# _cross_model_metrics.yml

metrics:
  - name: crime_rate_per_100k
    type: derived
    label: "Crime Rate per 100k Residents"
    description: >
      Crimes per 100k residents, computed live from fct_crimes +
      fct_income_population — replaces three separate hand-computed
      crime_per_100k columns in the old rpt_* layer.
    expr: "crime_to_population_ratio * 100000"
    input_metrics:
      - name: crime_to_population_ratio

  - name: crime_to_population_ratio
    type: ratio
    label: "Crime-to-Population Ratio"
    description: >
      Total crimes divided by average population, at whatever grain is
      queried. Joins fct_crimes and fct_income_population via the
      shared geo entity.
    numerator: total_crimes
    denominator: avg_total_population
""".strip(),
        language="yaml",
    )

with tab_sql:
    st.caption(
        "Equivalent SQL that MetricFlow would generate for `crime_rate_per_100k` "
        "grouped by `county_name`:"
    )
    st.code(
        """
-- MetricFlow pre-aggregates each fact before joining (avoids fan-out).
-- Divides by 27 (years 1997-2024) for an annualised rate.

WITH crime_totals AS (
    SELECT g.county_name,
           SUM(f.crime_count)      AS total_crimes_27yr,
           SUM(f.crime_count) / 27 AS annual_avg_crimes
    FROM COLORADO_CRIME_DB_PROD.GOLD.FCT_CRIMES       f
    JOIN COLORADO_CRIME_DB_PROD.GOLD.DIM_GEOGRAPHY    g ON f.geo_key = g.geo_key
    WHERE g.city_name = '[County Level]'   -- county grain
    GROUP BY g.county_name
),
pop_avg AS (
    SELECT g.county_name, AVG(ip.total_population) AS avg_population
    FROM COLORADO_CRIME_DB_PROD.GOLD.FCT_INCOME_POPULATION ip
    JOIN COLORADO_CRIME_DB_PROD.GOLD.DIM_GEOGRAPHY          g ON ip.geo_key = g.geo_key
    WHERE g.city_name = '[County Level]'
    GROUP BY g.county_name
)
SELECT
    c.county_name,
    c.total_crimes_27yr,
    ROUND(c.annual_avg_crimes, 0)                                               AS annual_avg_crimes,
    ROUND(p.avg_population, 0)                                                  AS avg_population,
    ROUND(c.annual_avg_crimes * 100000.0 / NULLIF(p.avg_population, 0), 1)     AS annual_crime_rate_per_100k
FROM crime_totals c
JOIN pop_avg      p ON c.county_name = p.county_name
ORDER BY annual_crime_rate_per_100k DESC
LIMIT 15
""".strip(),
        language="sql",
    )

with tab_chart:
    with st.spinner("Running cross-model metric query…"):
        df_spotlight = run_crime_rate_spotlight(session)

    if not df_spotlight.empty:
        fig = px.bar(
            df_spotlight.sort_values("CRIME_RATE_PER_100K", ascending=True),
            x="CRIME_RATE_PER_100K",
            y="COUNTY_NAME",
            orientation="h",
            color="CRIME_RATE_PER_100K",
            color_continuous_scale=["#1a1f2e", PALETTE["primary"]],
            labels={
                "CRIME_RATE_PER_100K": "Cumulative Crimes per 100k Residents (1997-2024)",
                "COUNTY_NAME": "",
            },
            title="crime_rate_per_100k — Top 15 Colorado Counties (27-year cumulative)",
            text="CRIME_RATE_PER_100K",
        )
        fig.update_traces(texttemplate="%{text:,.0f}", textposition="outside", marker_line_width=0)
        fig.update_layout(
            height=520,
            coloraxis_showscale=False,
            margin=dict(l=160, r=80, t=50, b=20),
        )
        st.plotly_chart(fig, width="stretch")
        st.caption(
            f"↳ Live from Snowflake · {len(df_spotlight):,} counties · "
            "RPT_COUNTY_AGENCY_CRIME_BASELINE x FCT_INCOME_POPULATION via DIM_GEOGRAPHY"
        )
        st.info(
            "📌 **Note on scale:** `total_crimes` reflects cumulative 27-year NIBRS "
            "administrative records (1997-2024). NIBRS generates multiple records per "
            "physical incident (one per offender x victim x offense combination), so "
            "absolute values are higher than unique incident counts. "
            "The relative ranking across counties is correct."
        )
    else:
        st.info("No data returned. Check Snowflake connection.")

st.divider()

# ══════════════════════════════════════════════════════════════════════════════
# Section 4 — Saved Queries
# ══════════════════════════════════════════════════════════════════════════════
st.subheader("💾 MetricFlow Saved Queries")
st.markdown(
    "Saved queries are pre-built, reusable metric requests defined in `_saved_queries.yml`. "
    "They act as a semantic API contract between the dbt project and downstream BI tools — "
    "the equivalent of a view in the semantic layer."
)

for sq in SAVED_QUERIES:
    with st.expander(f"**{sq['label']}** — `{sq['name']}`", expanded=False):
        st.markdown(f"_{sq['description']}_")

        col_left, col_right = st.columns(2)
        with col_left:
            st.markdown("**Metrics**")
            for m in sq["metrics"]:
                st.markdown(f"- `{m}`")
            st.markdown("**Group by**")
            for g in sq["group_by"]:
                st.markdown(f"- `{g}`")

        with col_right:
            st.markdown("**`mf query` CLI equivalent**")
            st.code(sq["mf_command"], language="bash")

        st.markdown("**Equivalent SQL**")
        st.code(sq["sql"], language="sql")

        if st.button("▶ Run live on Snowflake", key=f"run_{sq['name']}"):
            with st.spinner("Querying Snowflake…"):
                df_result = run_saved_query(session, sq["name"])
            if not df_result.empty:
                st.dataframe(df_result, width="stretch", hide_index=True)
                st.caption(f"↳ {len(df_result):,} rows returned")
            else:
                st.info("No results returned.")

st.divider()

# ── Closing narrative ──────────────────────────────────────────────────────────
st.markdown(
    """
    <div class="narrative-hook">
        The semantic layer is the <strong>contract</strong> between the engineering team and
        every downstream consumer — dashboards, AI, analysts, and stakeholders.
        15 metrics. 3 semantic models. 1 cross-model join that eliminates three redundant
        SQL files. Version-controlled, tested, and deployed via dbt-core.<br><br>
        This is what production-grade metric governance looks like.
    </div>
    """,
    unsafe_allow_html=True,
)

# ── Navigation ─────────────────────────────────────────────────────────────────
st.divider()
col_nav1, _ = st.columns(2)
col_nav1.page_link("pages/6_💬_Ask_the_Data.py", label="← Ask the Data", icon="💬")
