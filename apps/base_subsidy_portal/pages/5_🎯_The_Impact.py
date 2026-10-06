"""
Page 5 — 🎯 The Impact

Act 5 of the B.A.S.E. data narrative.

"Every act needs a measurable outcome. Act 5 closes the loop:
 each police agency in Colorado now has a data-derived crime reduction
 target — a 5% reduction from their historical baseline."

County KPI 1: Agency crime baseline + 5% reduction goal.

Charts:
  - Statewide summary KPI cards
  - County selector → filters all charts
  - Bullet chart: baseline crime count + target per agency
  - Gap table: agencies ranked by absolute crimes-to-save
"""

import plotly.graph_objects as go
import streamlit as st
from components.data_loaders import get_session, load_agency_crime_baseline
from components.styles import PALETTE, act_header, inject_css

# ── Page setup ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="The Impact · B.A.S.E. Portal",
    page_icon="🎯",
    layout="wide",
)
inject_css()
session = get_session()

# ── Act header ────────────────────────────────────────────────────────────────
act_header(
    5,
    "The Impact",
    "Every act needs a measurable outcome. This is it: a data-derived 5% crime "
    "reduction target for every police agency in Colorado, calculated from 23 years "
    "of historical incident records.",
)

# ── Load data ─────────────────────────────────────────────────────────────────
with st.spinner("Loading agency baselines from Snowflake…"):
    df = load_agency_crime_baseline(session)

if df.empty:
    st.error("No agency baseline data returned. Check Snowflake connection.")
    st.stop()

# Compute reduction gap
df["CRIMES_TO_SAVE"] = df["TOTAL_CRIMES"] - df["TARGET_CRIMES_5PCT_REDUCTION"]

# ── Statewide KPI cards ───────────────────────────────────────────────────────
total_agencies = df["AGENCY_NAME"].nunique()
total_counties = df["COUNTY_NAME"].nunique()
total_baseline = df["TOTAL_CRIMES"].sum()
total_target = df["TARGET_CRIMES_5PCT_REDUCTION"].sum()
total_to_save = total_baseline - total_target

c1, c2, c3, c4 = st.columns(4)
c1.metric("Police Agencies", f"{total_agencies:,}", help="Unique agencies with crime records")
c2.metric(
    "Counties Covered", f"{total_counties}", help="Counties with at least one agency in the dataset"
)
c3.metric(
    "Baseline Crime Count",
    f"{total_baseline:,}",
    help="Total historical incidents across all agencies",
)
c4.metric(
    "Statewide Crimes-to-Save",
    f"{total_to_save:,}",
    "-5% target",
    help="Incidents eliminated if every agency hits its 5% reduction goal",
)

st.divider()

# ── County selector ───────────────────────────────────────────────────────────
counties_available = sorted(df["COUNTY_NAME"].dropna().unique())
default_county = "El Paso" if "El Paso" in counties_available else counties_available[0]

selected_county = st.selectbox(
    "Select a county to drill into its agencies",
    options=counties_available,
    index=counties_available.index(default_county),
    key="county_select_impact",
)

df_county = (
    df[df["COUNTY_NAME"] == selected_county]
    .sort_values("TOTAL_CRIMES", ascending=False)
    .reset_index(drop=True)
)

if df_county.empty:
    st.info(f"No agency data found for {selected_county} County.")
    st.stop()

# County-level summary
county_agencies = len(df_county)
county_baseline = df_county["TOTAL_CRIMES"].sum()
county_to_save = df_county["CRIMES_TO_SAVE"].sum()

cc1, cc2, cc3 = st.columns(3)
cc1.metric(f"Agencies in {selected_county}", f"{county_agencies}")
cc2.metric("County Baseline Crimes", f"{county_baseline:,}")
cc3.metric("County Crimes-to-Save", f"{county_to_save:,}", "-5%")

st.divider()

# ── Chart 1: Bullet chart — baseline vs target per agency ─────────────────────
st.subheader(f"County KPI 1 — Agency Crime Reduction Targets: {selected_county} County")
st.caption(
    "Each bar shows the historical crime baseline. "
    "The orange marker shows the 5% reduction target. "
    "The gap between bar and marker = crimes to eliminate."
)

fig_bullet = go.Figure()

agencies = df_county["AGENCY_NAME"].tolist()
baselines = df_county["TOTAL_CRIMES"].tolist()
targets = df_county["TARGET_CRIMES_5PCT_REDUCTION"].tolist()

# Baseline bars
fig_bullet.add_trace(
    go.Bar(
        name="Historical Baseline",
        x=baselines,
        y=agencies,
        orientation="h",
        marker=dict(
            color=[PALETTE["bg_border"]] * len(agencies),
            line=dict(width=0),
        ),
        width=0.55,
        hovertemplate="<b>%{y}</b><br>Baseline: %{x:,} crimes<extra></extra>",
    )
)

# Target markers — drawn as a thin bar on top to simulate bullet chart targets
fig_bullet.add_trace(
    go.Bar(
        name="5% Reduction Target",
        x=targets,
        y=agencies,
        orientation="h",
        marker=dict(
            color=[PALETTE["primary"]] * len(agencies),
            line=dict(width=0),
            opacity=0.85,
        ),
        width=0.55,
        hovertemplate="<b>%{y}</b><br>Target: %{x:,} crimes<extra></extra>",
    )
)

fig_bullet.update_layout(
    barmode="overlay",  # overlay so target sits on top of baseline
    height=max(350, county_agencies * 36),
    xaxis=dict(title="Crime Count", showgrid=True),
    yaxis=dict(
        showgrid=False,
        autorange="reversed",  # most impactful agency at top
        tickfont=dict(size=11),
    ),
    legend=dict(orientation="h", y=1.06),
    margin=dict(l=200, r=40, t=40, b=40),
)

st.plotly_chart(fig_bullet, width="stretch")

st.divider()

# ── Chart 2: Gap ranking table ────────────────────────────────────────────────
st.subheader(f"Agency Reduction Opportunity — {selected_county} County")
st.caption(
    "Agencies ranked by absolute crimes-to-save (baseline - target). "
    "Highest opportunity at top — these agencies represent the largest "
    "impact from focused crime reduction resources."
)

df_table = (
    df_county[["AGENCY_NAME", "TOTAL_CRIMES", "TARGET_CRIMES_5PCT_REDUCTION", "CRIMES_TO_SAVE"]]
    .sort_values("CRIMES_TO_SAVE", ascending=False)
    .reset_index(drop=True)
    .rename(
        columns={
            "AGENCY_NAME": "Agency",
            "TOTAL_CRIMES": "Baseline Crimes",
            "TARGET_CRIMES_5PCT_REDUCTION": "5% Target",
            "CRIMES_TO_SAVE": "Crimes to Save",
        }
    )
)
df_table.index = df_table.index + 1

st.dataframe(
    df_table,
    width="stretch",
    column_config={
        "Agency": st.column_config.TextColumn("Agency"),
        "Baseline Crimes": st.column_config.NumberColumn("Baseline Crimes", format="%d"),
        "5% Target": st.column_config.NumberColumn("5% Target", format="%d"),
        "Crimes to Save": st.column_config.ProgressColumn(
            "Crimes to Save",
            min_value=0,
            max_value=int(df_county["CRIMES_TO_SAVE"].max()),
            format="%d",
        ),
    },
    height=min(500, 40 + county_agencies * 38),
)

st.divider()

# ── Narrative close ────────────────────────────────────────────────────────────
st.markdown(
    """
    <div class="narrative-hook">
        The data story is complete. Nine million incidents → 64 county profiles →
        3.1 million business scores → one measurable goal per agency.
        This is what a production-grade data pipeline looks like in practice.<br><br>
        <strong>Next:</strong> Ask the data a question directly using Snowflake Cortex Analyst →
    </div>
    """,
    unsafe_allow_html=True,
)

# ── Navigation ────────────────────────────────────────────────────────────────
col_nav1, col_nav2 = st.columns(2)
col_nav1.page_link("pages/4_🏢_The_Solution.py", label="← The Solution", icon="🏢")
col_nav2.page_link("pages/6_💬_Ask_the_Data.py", label="Next: Ask the Data →", icon="💬")
