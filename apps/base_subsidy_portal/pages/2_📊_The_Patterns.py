"""
Page 2 — 📊 The Patterns

Act 2 of the B.A.S.E. data narrative.

"Crime isn't random. It has rhythms — seasonal pulses, weekly cycles,
 day-and-night signatures — and those patterns tell us where to deploy resources."

Shows WHEN crime happens, at county and city grain:
  - County KPI 6: Seasonal crime heatmap (month x county)
  - City KPI 6:   Day-of-week crime area chart (city selector)
  - City KPI 2+4: Day vs Night top-3 crime categories (lollipop)
  - City KPI 3:   Average offender age by crime type (dot plot)
"""

import plotly.graph_objects as go
import streamlit as st
from components.data_loaders import (
    get_session,
    load_city_crime_demographics,
    load_city_time_of_day_crimes,
    load_city_time_trends,
    load_county_monthly_crimes,
)
from components.styles import PALETTE, act_header, inject_css

# ── Page setup ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="The Patterns · B.A.S.E. Portal",
    page_icon="📊",
    layout="wide",
)
inject_css()

# ── Session ───────────────────────────────────────────────────────────────────
session = get_session()

# ── Act header ────────────────────────────────────────────────────────────────
act_header(
    2,
    "The Patterns",
    "Crime isn't random. It has rhythms — seasonal pulses, weekly cycles, "
    "and day-and-night signatures. These patterns tell us where to deploy resources.",
)

# ── Load data ─────────────────────────────────────────────────────────────────
with st.spinner("Querying Snowflake…"):
    df_monthly = load_county_monthly_crimes(session)
    df_trends = load_city_time_trends(session)
    df_tod = load_city_time_of_day_crimes(session)
    df_demo = load_city_crime_demographics(session)

# ── City selector (drives charts 2, 3, 4) ─────────────────────────────────────
available_cities = sorted(df_trends["CITY_NAME"].dropna().unique())
default_city = "Denver" if "Denver" in available_cities else available_cities[0]

selected_city = st.selectbox(
    "Select a city for city-level charts (charts 2, 3, 4)",
    options=available_cities,
    index=available_cities.index(default_city),
    key="city_selector",
)

st.divider()

# ── Chart 1: Seasonal heatmap — county x month ────────────────────────────────
st.subheader("County KPI 6 — Seasonal Crime Heatmap (All Counties)")
st.caption(
    "Each row is a county; each column is a month (Jan-Dec). "
    "Darker orange = more crimes. Scroll vertically to see all 64 counties."
)

# Aggregate across all years: sum total_crimes per county x month
df_heat = (
    df_monthly.groupby(["COUNTY_NAME", "MONTH", "MONTH_NAME"], as_index=False)["TOTAL_CRIMES"]
    .sum()
    .sort_values(["COUNTY_NAME", "MONTH"])
)

# Pivot to wide: counties as rows, months as columns
MONTH_ORDER = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
]
df_heat_pivot = (
    df_heat.pivot_table(
        index="COUNTY_NAME", columns="MONTH_NAME", values="TOTAL_CRIMES", aggfunc="sum"
    )
    .fillna(0)
    .reindex(columns=MONTH_ORDER, fill_value=0)
    .sort_index()  # alphabetical counties
)

fig_heat = go.Figure(
    go.Heatmap(
        z=df_heat_pivot.values,
        x=df_heat_pivot.columns.tolist(),
        y=df_heat_pivot.index.tolist(),
        colorscale=PALETTE["scale"],
        hovertemplate="<b>%{y}</b><br>%{x}: %{z:,.0f} crimes<extra></extra>",
        colorbar=dict(
            title="Total Crimes",
            thickness=14,
            tickfont=dict(color=PALETTE["text_muted"]),
            title_font=dict(color=PALETTE["text_muted"]),
        ),
    )
)
fig_heat.update_layout(
    height=900,
    xaxis=dict(side="top", tickangle=0, showgrid=False),
    yaxis=dict(showgrid=False, autorange="reversed"),
    margin=dict(l=140, r=20, t=40, b=20),
)
st.plotly_chart(fig_heat, width="stretch")

st.divider()

# ── Row 2: Day-of-week + Day/Night charts ─────────────────────────────────────
col_left, col_right = st.columns([1, 1], gap="large")

# ── Chart 2: Day-of-week area chart ───────────────────────────────────────────
with col_left:
    st.subheader(f"City KPI 6 — Weekly Crime Rhythm: {selected_city}")
    st.caption("Average crimes per day of week — reveals weekend or mid-week spikes.")

    df_dow = (
        df_trends[df_trends["CITY_NAME"] == selected_city]
        .groupby(["DAY_OF_WEEK", "DAY_NAME"], as_index=False)["TOTAL_CRIMES"]
        .sum()
        .sort_values("DAY_OF_WEEK")
    )

    # Day ordering: 1=Sunday … 7=Saturday
    DOW_LABELS = {1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"}
    df_dow["DAY_LABEL"] = df_dow["DAY_OF_WEEK"].map(DOW_LABELS)

    if df_dow.empty:
        st.info(f"No city-level data for {selected_city}.")
    else:
        fig_dow = go.Figure()
        fig_dow.add_trace(
            go.Scatter(
                x=df_dow["DAY_LABEL"],
                y=df_dow["TOTAL_CRIMES"],
                mode="lines+markers",
                fill="tozeroy",
                fillcolor="rgba(255, 107, 53, 0.15)",
                line=dict(color=PALETTE["primary"], width=2.5),
                marker=dict(size=8, color=PALETTE["primary"]),
                hovertemplate="%{x}: %{y:,.0f} crimes<extra></extra>",
            )
        )
        fig_dow.update_layout(
            height=340,
            xaxis=dict(showgrid=False),
            yaxis=dict(title="Total Crimes"),
        )
        st.plotly_chart(fig_dow, width="stretch")

# ── Chart 3: Day vs Night lollipop ────────────────────────────────────────────
with col_right:
    st.subheader(f"City KPI 2 & 4 — Day vs Night Crime: {selected_city}")
    st.caption("Top 3 crime categories during daytime (6AM-6PM) vs nighttime (6PM-6AM).")

    df_tod_city = df_tod[df_tod["CITY_NAME"] == selected_city].sort_values(["TIME_OF_DAY", "RNK"])

    if df_tod_city.empty:
        st.info(f"No time-of-day data for {selected_city}.")
    else:
        fig_lollipop = go.Figure()
        tod_colors = {"day": "#D4A017", "night": "#4C9BE8"}

        for tod_val, group in df_tod_city.groupby("TIME_OF_DAY"):
            label = "☀️ Daytime" if tod_val == "day" else "🌙 Nighttime"
            color = tod_colors.get(tod_val, PALETTE["primary"])

            # Stems
            for _, row in group.iterrows():
                fig_lollipop.add_shape(
                    type="line",
                    x0=0,
                    x1=row["CRIME_COUNT"],
                    y0=f"{tod_val}-{row['OFFENSE_CATEGORY_NAME']}",
                    y1=f"{tod_val}-{row['OFFENSE_CATEGORY_NAME']}",
                    line=dict(color=color, width=2),
                )

            # Dots
            fig_lollipop.add_trace(
                go.Scatter(
                    x=group["CRIME_COUNT"],
                    y=[f"{tod_val}-{r}" for r in group["OFFENSE_CATEGORY_NAME"]],
                    mode="markers",
                    name=label,
                    marker=dict(size=12, color=color),
                    customdata=group[["OFFENSE_CATEGORY_NAME", "CRIME_COUNT"]].values,
                    hovertemplate=(
                        "<b>%{customdata[0]}</b><br>"
                        f"{label}: %{{customdata[1]:,}} crimes<extra></extra>"
                    ),
                )
            )

        fig_lollipop.update_layout(
            height=340,
            xaxis=dict(title="Crime Count"),
            yaxis=dict(
                ticktext=[
                    f"{r['OFFENSE_CATEGORY_NAME']} ({r['TIME_OF_DAY']})"
                    for _, r in df_tod_city.iterrows()
                ],
                tickvals=[
                    f"{r['TIME_OF_DAY']}-{r['OFFENSE_CATEGORY_NAME']}"
                    for _, r in df_tod_city.iterrows()
                ],
                showgrid=False,
            ),
            legend=dict(orientation="h", y=1.12),
        )
        st.plotly_chart(fig_lollipop, width="stretch")

st.divider()

# ── Chart 4: Dot plot — avg offender age by crime category ───────────────────
st.subheader(f"City KPI 3 — Avg Offender Age by Crime Type: {selected_city}")
st.caption(
    "Average age of individuals involved per offense category. "
    "NULL ages (~47% of incidents) are excluded — interpret cautiously."
)

df_age = df_demo[
    (df_demo["CITY_NAME"] == selected_city) & (df_demo["AVG_OFFENDER_AGE"].notna())
].sort_values("AVG_OFFENDER_AGE", ascending=True)

if df_age.empty:
    st.info(f"No age data available for {selected_city}.")
else:
    crime_against_palette = {
        "Property": PALETTE["property"],
        "Person": PALETTE["person"],
        "Society": PALETTE["society"],
    }

    fig_dot = go.Figure()
    for ca, group in df_age.groupby("CRIME_AGAINST"):
        fig_dot.add_trace(
            go.Scatter(
                x=group["AVG_OFFENDER_AGE"],
                y=group["OFFENSE_CATEGORY_NAME"],
                mode="markers",
                name=ca,
                marker=dict(
                    size=14,
                    color=crime_against_palette.get(ca, PALETTE["primary"]),
                    line=dict(width=1, color=PALETTE["bg_border"]),
                ),
                hovertemplate=(
                    f"<b>%{{y}}</b><br>Crime against: {ca}<br>Avg age: %{{x:.1f}}<extra></extra>"
                ),
            )
        )

    fig_dot.update_layout(
        height=400,
        xaxis=dict(title="Average Offender Age (years)", range=[15, 60]),
        yaxis=dict(showgrid=False),
        legend=dict(title="Crime Against", orientation="h", y=1.08),
    )
    st.plotly_chart(fig_dot, width="stretch")

st.divider()

# ── Narrative close ────────────────────────────────────────────────────────────
st.markdown(
    """
    <div class="narrative-hook">
        Summer peaks. Weekend surges. Night-time property crime.
        The patterns are consistent — but the <em>intensity</em> varies dramatically
        across Colorado's income landscape.
        Act 3 asks: <strong>who bears the burden?</strong>
    </div>
    """,
    unsafe_allow_html=True,
)

col_nav1, col_nav2 = st.columns(2)
col_nav1.page_link("pages/1_🗺️_The_Landscape.py", label="← The Landscape", icon="🗺️")
col_nav2.page_link("pages/3_💰_The_Disparity.py", label="Next: The Disparity →", icon="💰")
