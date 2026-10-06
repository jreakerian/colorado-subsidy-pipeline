"""
Page 1 — 🗺️ The Landscape

Act 1 of the B.A.S.E. data narrative.

"Before we can solve a problem, we need to see it."

Shows WHERE crime is concentrated across Colorado's 64 counties:
  - County KPI 7: Crime rate per 100K residents (choropleth)
  - Top 15 counties by raw crime volume (bar chart)
  - County KPI 10: Crime-against type distribution (stacked bar)

Charts join on county NAME (title case) — the GeoJSON uses featureidkey="properties.NAME".
"""

import json
from pathlib import Path

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

from components.data_loaders import (
    get_session,
    load_crime_categories_by_county,
    load_crime_density_by_county,
    load_crime_type_distribution_by_county,
)
from components.styles import PALETTE, inject_css, act_header

# ── Page setup ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="The Landscape · B.A.S.E. Portal",
    page_icon="🗺️",
    layout="wide",
)
inject_css()

# ── Session & GeoJSON ─────────────────────────────────────────────────────────
session = get_session()

GEOJSON_PATH = Path(__file__).parent.parent / "assets" / "colorado_counties.geojson"
with open(GEOJSON_PATH) as f:
    co_geojson = json.load(f)

# ── Act header ────────────────────────────────────────────────────────────────
act_header(
    1,
    "The Landscape",
    "9 million crime incidents. 64 counties. 23 years. "
    "Before we can fix it, we need to see it — county by county.",
)

# ── Load data ─────────────────────────────────────────────────────────────────
with st.spinner("Querying Snowflake…"):
    df_density  = load_crime_density_by_county(session)
    df_type_dist = load_crime_type_distribution_by_county(session)
    df_categories = load_crime_categories_by_county(session)

# ── Chart 1: Bubble Map — Crime Rate per 100K ────────────────────────────────
st.subheader("County KPI 7 — Crime Rate per 100,000 Residents")
st.caption(
    "Bubble size and colour both encode crime rate per 100K residents — "
    "eliminating the area bias of a choropleth. Large rural counties no longer "
    "dominate visually. Hover a bubble for details."
)

# Derive county centroids from the GeoJSON already in memory (no extra data source)
def _centroid(geometry):
    """Rough centroid: mean of the exterior ring coordinates."""
    if geometry["type"] == "Polygon":
        coords = geometry["coordinates"][0]
    elif geometry["type"] == "MultiPolygon":
        coords = max(geometry["coordinates"], key=lambda p: len(p[0]))[0]
    else:
        return None, None
    lons = [c[0] for c in coords]
    lats = [c[1] for c in coords]
    return sum(lats) / len(lats), sum(lons) / len(lons)

centroids_df = pd.DataFrame(
    [
        {
            "COUNTY_NAME": f["properties"]["NAME"],
            "lat": _centroid(f["geometry"])[0],
            "lon": _centroid(f["geometry"])[1],
        }
        for f in co_geojson["features"]
    ]
)
df_bubble = df_density.merge(centroids_df, on="COUNTY_NAME", how="left")

fig_map = px.scatter_map(
    df_bubble,
    lat="lat",
    lon="lon",
    size="CRIME_RATE_PER_100K",
    color="CRIME_RATE_PER_100K",
    color_continuous_scale=PALETTE["scale"],
    range_color=(
        df_density["CRIME_RATE_PER_100K"].quantile(0.05),
        df_density["CRIME_RATE_PER_100K"].quantile(0.95),
    ),
    size_max=55,
    map_style="carto-darkmatter",
    zoom=5.5,
    center={"lat": 39.0, "lon": -105.5},
    hover_name="COUNTY_NAME",
    hover_data={
        "lat": False,
        "lon": False,
        "CRIME_RATE_PER_100K": ":.1f",
        "TOTAL_CRIMES": ":,",
        "AVG_POPULATION": ":.0f",
    },
    labels={
        "CRIME_RATE_PER_100K": "Crimes / 100K",
        "TOTAL_CRIMES": "Total Crimes",
        "AVG_POPULATION": "Avg Population",
    },
    text="COUNTY_NAME",
)
fig_map.update_traces(
    textposition="top center",
    textfont=dict(size=9, color="rgba(230,237,243,0.7)"),
    marker=dict(opacity=0.80),
)
fig_map.update_layout(
    height=500,
    margin=dict(l=0, r=0, t=0, b=0),
    coloraxis_colorbar=dict(
        title="Per 100K",
        thickness=14,
        len=0.6,
        tickfont=dict(color=PALETTE["text_muted"]),
        title_font=dict(color=PALETTE["text_muted"]),
    ),
)
st.plotly_chart(fig_map, width="stretch")

st.divider()

# ── County filter — below choropleth, drives charts 2 & 3 ────────────────────
all_counties = sorted(df_density["COUNTY_NAME"].dropna().unique())
selected_counties = st.multiselect(
    "Filter by county — applies to charts below (leave blank for all)",
    options=all_counties,
    default=[],
    key="county_filter",
)
filtering = bool(selected_counties)
active_counties = selected_counties if filtering else all_counties

# ── Charts 2 & 3 side by side ─────────────────────────────────────────────────
col_left, col_right = st.columns([1, 1], gap="large")

# ── Chart 2: Crime volume bar chart ───────────────────────────────────────────
with col_left:
    if filtering:
        st.subheader(f"Crime Volume — {len(active_counties)} Selected {'County' if len(active_counties) == 1 else 'Counties'}")
        st.caption("Filtered to your selection, sorted by total crime volume.")
        df_bar = (
            df_density[df_density["COUNTY_NAME"].isin(active_counties)]
            .sort_values("TOTAL_CRIMES", ascending=True)
        )
    else:
        st.subheader("Top 15 Counties — Total Crime Volume")
        st.caption("Raw incident count; dominated by population centres (Denver, El Paso, Arapahoe).")
        df_bar = (
            df_density
            .nlargest(15, "TOTAL_CRIMES")
            .sort_values("TOTAL_CRIMES", ascending=True)
        )

    fig_bar = px.bar(
        df_bar,
        x="TOTAL_CRIMES",
        y="COUNTY_NAME",
        orientation="h",
        color="CRIME_RATE_PER_100K",
        color_continuous_scale=PALETTE["scale"],
        text="TOTAL_CRIMES",
        labels={
            "TOTAL_CRIMES": "Total Crimes",
            "COUNTY_NAME": "",
            "CRIME_RATE_PER_100K": "Rate / 100K",
        },
    )
    fig_bar.update_traces(
        texttemplate="%{x:,.0f}",
        textposition="outside",
        marker_line_width=0,
    )
    fig_bar.update_layout(
        height=max(300, len(df_bar) * 28),
        showlegend=False,
        xaxis=dict(showgrid=True),
        coloraxis_showscale=False,
    )
    st.plotly_chart(fig_bar, width="stretch")

# ── Chart 3: Stacked bar — crime-against breakdown ────────────────────────────
with col_right:
    st.subheader("County KPI 10 — Crime Type Distribution")
    st.caption(
        "Property crimes dominate statewide, but the Person-crime share "
        "reveals where violence is concentrated."
    )

    df_type_filtered = df_type_dist[df_type_dist["COUNTY_NAME"].isin(active_counties)]

    df_pivot = (
        df_type_filtered
        .pivot_table(
            index="COUNTY_NAME",
            columns="CRIME_AGAINST",
            values="PCT_OF_COUNTY_CRIMES",
            aggfunc="sum",
        )
        .fillna(0)
        .reset_index()
        .sort_values("Property", ascending=False)
    )
    # When filtered show all selected; when unfiltered cap at 20 for readability
    if not filtering:
        df_pivot = df_pivot.head(20)

    fig_stacked = go.Figure()
    for category in ["Property", "Person", "Society"]:
        if category in df_pivot.columns:
            fig_stacked.add_trace(
                go.Bar(
                    name=category,
                    x=df_pivot["COUNTY_NAME"],
                    y=df_pivot[category],
                    marker_color=PALETTE.get(category.lower(), PALETTE["primary"]),
                    hovertemplate="%{y:.1f}%<extra>" + category + "</extra>",
                )
            )
    fig_stacked.update_layout(
        barmode="stack",
        height=max(350, len(df_pivot) * 18),
        xaxis=dict(tickangle=-45, showgrid=False),
        yaxis=dict(title="% of County Crimes", ticksuffix="%"),
        legend=dict(orientation="h", y=1.08),
    )
    st.plotly_chart(fig_stacked, width="stretch")


st.divider()

# ── Narrative close ────────────────────────────────────────────────────────────
st.markdown(
    """
    <div class="narrative-hook">
        The choropleth reveals an uncomfortable truth: the counties with the <em>lowest 
        raw crime counts</em> often carry the <em>highest per-capita rates</em>. 
        Rural Colorado is not as safe as the numbers first suggest. 
        Act 2 asks: <strong>when</strong> does this crime happen?
    </div>
    """,
    unsafe_allow_html=True,
)

col_nav1, col_nav2 = st.columns(2)
col_nav2.page_link("pages/2_📊_The_Patterns.py", label="Next: The Patterns →", icon="📊")
