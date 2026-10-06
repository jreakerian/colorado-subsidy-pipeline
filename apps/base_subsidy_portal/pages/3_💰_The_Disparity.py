"""
Page 3 — 💰 The Disparity

Act 3 of the B.A.S.E. data narrative.

"High crime isn't evenly distributed. It falls hardest on counties
 where incomes are lowest and population pressure is highest."

Shows the socioeconomic dimension of crime:
  - County KPI 9: Crime rate vs median household income (scatter + trendline)
  - County KPIs 3+8: Population growth vs crime rate (diverging bar)
  - County KPI 4: Per-capita income trends over time (sparklines for high-crime counties)
  - Composite vulnerability ranking table (all 64 counties)
"""

import plotly.express as px
import plotly.graph_objects as go
import numpy as np
import streamlit as st

from components.data_loaders import (
    get_session,
    load_crime_vs_income,
    load_income_population_by_county,
    load_crime_density_by_county,
)
from components.styles import PALETTE, inject_css, act_header

# ── Page setup ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="The Disparity · B.A.S.E. Portal",
    page_icon="💰",
    layout="wide",
)
inject_css()

# ── Session ───────────────────────────────────────────────────────────────────
session = get_session()

# ── Act header ────────────────────────────────────────────────────────────────
act_header(
    3,
    "The Disparity",
    "High crime doesn't fall randomly. It concentrates where incomes are lowest "
    "and population pressure is highest — and that's exactly where the B.A.S.E. "
    "program must intervene.",
)

# ── Load data ─────────────────────────────────────────────────────────────────
with st.spinner("Querying Snowflake…"):
    df_scatter   = load_crime_vs_income(session)
    df_income    = load_income_population_by_county(session)
    df_density   = load_crime_density_by_county(session)

# ── Chart 1: Scatter — Crime Rate vs Median Income ────────────────────────────
st.subheader("County KPI 9 — Crime Rate vs Median Household Income")
st.caption(
    "Each dot is a county. OLS trendline shows the inverse relationship: "
    "as median income rises, crime rate falls. Size = total population."
)

if not df_scatter.empty:
    # OLS trendline manually (avoids statsmodels dependency)
    x = df_scatter["AVG_MEDIAN_INCOME"].values
    y = df_scatter["CRIME_RATE_PER_100K"].values
    valid = ~(np.isnan(x) | np.isnan(y))
    x_v, y_v = x[valid], y[valid]
    m, b = np.polyfit(x_v, y_v, 1)
    x_line = np.linspace(x_v.min(), x_v.max(), 100)
    y_line = m * x_line + b

    fig_scatter = go.Figure()

    # Scatter dots
    fig_scatter.add_trace(
        go.Scatter(
            x=df_scatter["AVG_MEDIAN_INCOME"],
            y=df_scatter["CRIME_RATE_PER_100K"],
            mode="markers+text",
            text=df_scatter["COUNTY_NAME"],
            textposition="top center",
            textfont=dict(size=9, color=PALETTE["text_muted"]),
            marker=dict(
                size=df_scatter["AVG_POPULATION"].apply(
                    lambda p: max(8, min(28, p / 30_000))
                ),
                color=df_scatter["CRIME_RATE_PER_100K"],
                colorscale=PALETTE["scale"],
                showscale=True,
                colorbar=dict(
                    title="Rate / 100K",
                    thickness=12,
                    tickfont=dict(color=PALETTE["text_muted"]),
                    title_font=dict(color=PALETTE["text_muted"]),
                ),
                line=dict(width=0.5, color=PALETTE["bg_border"]),
            ),
            customdata=df_scatter[["COUNTY_NAME", "AVG_MEDIAN_INCOME", "AVG_POPULATION"]].values,
            hovertemplate=(
                "<b>%{customdata[0]}</b><br>"
                "Median Income: $%{customdata[1]:,.0f}<br>"
                "Crime Rate: %{y:.1f} per 100K<br>"
                "Avg Population: %{customdata[2]:,.0f}"
                "<extra></extra>"
            ),
            name="Counties",
        )
    )

    # OLS trendline
    fig_scatter.add_trace(
        go.Scatter(
            x=x_line,
            y=y_line,
            mode="lines",
            line=dict(color=PALETTE["primary"], width=2, dash="dot"),
            name="OLS Trendline",
            hoverinfo="skip",
        )
    )

    fig_scatter.update_layout(
        height=520,
        xaxis=dict(
            title="Avg Median Household Income ($)",
            tickprefix="$",
            tickformat=",.0f",
        ),
        yaxis=dict(title="Crime Rate per 100,000 Residents"),
        legend=dict(orientation="h", y=1.06),
    )
    st.plotly_chart(fig_scatter, width="stretch")
else:
    st.info("Scatter data not available — check Snowflake connection.")

st.divider()

# ── Chart 2: Diverging bar — population growth vs crime rate ──────────────────
st.subheader("County KPIs 3 & 8 — Population Growth vs Crime Rate")
st.caption(
    "Counties where population grows faster than infrastructure can adapt "
    "see compounding crime pressure. "
    "Bar length = population growth rate; color = crime rate per 100K."
)

# Get most recent year's population growth per county
df_growth = (
    df_income
    .dropna(subset=["POPULATION_GROWTH_PCT"])
    .sort_values("YEAR")
    .groupby("COUNTY_NAME")
    .last()
    .reset_index()
    [["COUNTY_NAME", "POPULATION_GROWTH_PCT", "TOTAL_POPULATION"]]
)

# Merge with crime rate
df_div = df_growth.merge(
    df_density[["COUNTY_NAME", "CRIME_RATE_PER_100K"]],
    on="COUNTY_NAME",
    how="inner",
).sort_values("POPULATION_GROWTH_PCT", ascending=True)

if not df_div.empty:
    # Show top 30 counties by absolute growth
    df_div_plot = df_div.nlargest(30, "TOTAL_POPULATION")

    fig_div = go.Figure(
        go.Bar(
            x=df_div_plot["POPULATION_GROWTH_PCT"],
            y=df_div_plot["COUNTY_NAME"],
            orientation="h",
            marker=dict(
                color=df_div_plot["CRIME_RATE_PER_100K"],
                colorscale=PALETTE["scale"],
                showscale=True,
                colorbar=dict(
                    title="Crime / 100K",
                    thickness=12,
                    tickfont=dict(color=PALETTE["text_muted"]),
                    title_font=dict(color=PALETTE["text_muted"]),
                ),
            ),
            customdata=df_div_plot[["COUNTY_NAME", "CRIME_RATE_PER_100K", "TOTAL_POPULATION"]].values,
            hovertemplate=(
                "<b>%{customdata[0]}</b><br>"
                "Pop Growth: %{x:.2f}%<br>"
                "Crime Rate: %{customdata[1]:.1f} per 100K<br>"
                "Population: %{customdata[2]:,.0f}"
                "<extra></extra>"
            ),
        )
    )
    fig_div.add_vline(
        x=0,
        line_color=PALETTE["bg_border"],
        line_width=1.5,
    )
    fig_div.update_layout(
        height=600,
        xaxis=dict(title="Population Growth Rate (%)", ticksuffix="%"),
        yaxis=dict(showgrid=False),
    )
    st.plotly_chart(fig_div, width="stretch")

st.divider()

# ── Chart 3: Sparklines — per-capita income trend (top 10 high-crime counties) ─
st.subheader("County KPI 4 — Per-Capita Income Trends (Top 10 Highest-Crime Counties)")
st.caption(
    "Income trajectories for the 10 counties with the highest crime rates. "
    "Stagnant or declining income alongside rising crime justifies targeted subsidy intervention."
)

top10_counties = (
    df_density
    .nlargest(10, "CRIME_RATE_PER_100K")["COUNTY_NAME"]
    .tolist()
)

df_income_top = df_income[df_income["COUNTY_NAME"].isin(top10_counties)].dropna(
    subset=["PER_CAPITA_INCOME", "YEAR"]
)

if not df_income_top.empty:
    fig_spark = go.Figure()
    color_list = [
        PALETTE["primary"], PALETTE["property"], PALETTE["society"],
        "#2EA043", "#D4A017", "#F85149", "#58A6FF",
        "#BC8CFF", "#79C0FF", "#56D364",
    ]
    for i, county in enumerate(top10_counties):
        df_c = df_income_top[df_income_top["COUNTY_NAME"] == county].sort_values("YEAR")
        if df_c.empty:
            continue
        fig_spark.add_trace(
            go.Scatter(
                x=df_c["YEAR"],
                y=df_c["PER_CAPITA_INCOME"],
                mode="lines",
                name=county,
                line=dict(color=color_list[i % len(color_list)], width=1.8),
                hovertemplate=(
                    f"<b>{county}</b><br>"
                    "Year: %{x}<br>"
                    "Per Capita Income: $%{y:,.0f}<extra></extra>"
                ),
            )
        )

    fig_spark.update_layout(
        height=380,
        xaxis=dict(title="Year", showgrid=True),
        yaxis=dict(title="Per Capita Income ($)", tickprefix="$", tickformat=",.0f"),
        legend=dict(orientation="v", x=1.01, y=1, font=dict(size=11)),
    )
    st.plotly_chart(fig_spark, width="stretch")

st.divider()

# ── Chart 4: Vulnerability ranking table ──────────────────────────────────────
st.subheader("Composite Vulnerability Ranking — All 64 Counties")
st.caption(
    "Counties ranked by a composite score: high crime rate + low income + "
    "high population growth. These are the primary targets of the B.A.S.E. program."
)

# Build composite score
df_rank = df_scatter.copy()

# Normalise each dimension to 0–1
for col_name in ["CRIME_RATE_PER_100K", "AVG_POPULATION"]:
    mn, mx = df_rank[col_name].min(), df_rank[col_name].max()
    df_rank[f"{col_name}_NORM"] = (df_rank[col_name] - mn) / (mx - mn + 1e-9)

# Invert income: low income = high score
inc_mn, inc_mx = df_rank["AVG_MEDIAN_INCOME"].min(), df_rank["AVG_MEDIAN_INCOME"].max()
df_rank["INCOME_NORM_INV"] = 1 - (df_rank["AVG_MEDIAN_INCOME"] - inc_mn) / (inc_mx - inc_mn + 1e-9)

df_rank["VULNERABILITY_SCORE"] = (
    df_rank["CRIME_RATE_PER_100K_NORM"] * 0.50
    + df_rank["INCOME_NORM_INV"] * 0.35
    + df_rank["AVG_POPULATION_NORM"] * 0.15
).round(3)

df_display = (
    df_rank
    .sort_values("VULNERABILITY_SCORE", ascending=False)
    .reset_index(drop=True)
    [["COUNTY_NAME", "CRIME_RATE_PER_100K", "AVG_MEDIAN_INCOME", "AVG_POPULATION", "VULNERABILITY_SCORE"]]
    .rename(columns={
        "COUNTY_NAME": "County",
        "CRIME_RATE_PER_100K": "Crime Rate / 100K",
        "AVG_MEDIAN_INCOME": "Avg Median Income",
        "AVG_POPULATION": "Avg Population",
        "VULNERABILITY_SCORE": "Vulnerability Score",
    })
)
df_display.index = df_display.index + 1  # 1-indexed rank
df_display["Avg Median Income"] = df_display["Avg Median Income"].apply(lambda v: f"${v:,.0f}")
df_display["Avg Population"]    = df_display["Avg Population"].apply(lambda v: f"{v:,.0f}")

st.dataframe(
    df_display,
    width="stretch",
    column_config={
        "Vulnerability Score": st.column_config.ProgressColumn(
            "Vulnerability Score",
            min_value=0,
            max_value=1,
            format="%.3f",
        ),
        "Crime Rate / 100K": st.column_config.NumberColumn(
            "Crime Rate / 100K",
            format="%.1f",
        ),
    },
    height=420,
)

st.divider()

# ── Narrative close ────────────────────────────────────────────────────────────
st.markdown(
    """
    <div class="narrative-hook">
        The data makes the case: crime clusters in counties with the fewest resources 
        to fight it. The <strong>B.A.S.E. program</strong> turns this analysis into action — 
        Act 4 shows exactly how 3.1 million Colorado businesses were scored and ranked 
        for security subsidy eligibility.
    </div>
    """,
    unsafe_allow_html=True,
)

col_nav1, col_nav2 = st.columns(2)
col_nav1.page_link("pages/2_📊_The_Patterns.py", label="← The Patterns", icon="📊")
col_nav2.page_link("pages/4_🏢_The_Solution.py", label="Next: The Solution →", icon="🏢")
