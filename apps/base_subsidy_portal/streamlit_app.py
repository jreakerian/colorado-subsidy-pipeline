"""
Colorado B.A.S.E. Analytics Portal — Landing Page

Business Assistance for Security Enhancements (B.A.S.E.)
A data-driven portfolio project demonstrating an end-to-end data engineering pipeline:
  9M+ crime records → Airflow → Snowflake → dbt → Streamlit + Cortex AI

Navigation: Use the sidebar to explore the 5-act data narrative and AI features.
"""

import streamlit as st
from components.data_loaders import get_session, load_headline_stats
from components.styles import inject_css

# ---------------------------------------------------------------------------
# Page config
# ---------------------------------------------------------------------------

st.set_page_config(
    page_title="Colorado B.A.S.E. Analytics Portal",
    page_icon="🏔️",
    layout="wide",
    initial_sidebar_state="expanded",
)

inject_css()

# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------

session = get_session()

# ---------------------------------------------------------------------------
# Hero section
# ---------------------------------------------------------------------------

st.markdown(
    """
    <div style="padding: 8px 0 4px 0;">
        <div style="
            display: inline-block;
            background: #FF6B35;
            color: #0D1117;
            font-size: 0.7rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.12em;
            padding: 4px 12px;
            border-radius: 4px;
            margin-bottom: 12px;
        ">Portfolio Project · Colorado OEDIT</div>
    </div>
    """,
    unsafe_allow_html=True,
)

st.title("Colorado B.A.S.E. Analytics Portal")
st.markdown(
    "**Business Assistance for Security Enhancements** — "
    "A fictional but data-grounded Colorado state program that allocates "
    "security subsidies to businesses using 23 years of crime, income, and "
    "population data."
)

st.divider()

# ---------------------------------------------------------------------------
# Headline KPI cards
# ---------------------------------------------------------------------------

with st.spinner("Loading pipeline statistics..."):
    try:
        stats = load_headline_stats(session)

        c1, c2, c3, c4 = st.columns(4)
        c1.metric(
            "Crime Incidents Processed",
            f"{stats['total_crimes']:,}",
            help="Total rows ingested from 2 Colorado crime datasets (1997-2020)",
        )
        c2.metric(
            "Counties Analyzed",
            f"{stats['counties']}",
            help="All 64 Colorado counties covered",
        )
        c3.metric(
            "Businesses Scored",
            f"{stats['total_businesses']:,}",
            help="Colorado Secretary of State registered entities with assigned B.A.S.E. tier",
        )
        c4.metric(
            "Years of Data",
            f"{stats['years_of_data']} yrs",
            f"{stats['year_min']}-{stats['year_max']}",
            help="Longitudinal crime and socioeconomic data",
        )
    except Exception as e:
        st.warning(f"Could not load live stats — check Snowflake connection. ({e})")
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Crime Incidents Processed", "9,048,771")
        c2.metric("Counties Analyzed", "64")
        c3.metric("Businesses Scored", "3.1M+")
        c4.metric("Years of Data", "23 yrs", "1997-2020")

st.divider()

# ---------------------------------------------------------------------------
# The data narrative
# ---------------------------------------------------------------------------

st.subheader("The Data Narrative")
st.markdown(
    "This portal tells a five-act story about crime, inequality, and intervention "
    "across Colorado — from raw incident data to a subsidy program that targets "
    "resources where they're needed most."
)

acts = [
    ("🗺️", "Act 1 — The Landscape", "Where is crime happening across Colorado's 64 counties?"),
    ("📊", "Act 2 — The Patterns", "When does crime peak — by season, day of week, and hour?"),
    (
        "💰",
        "Act 3 — The Disparity",
        "How do income and population growth correlate with crime rates?",
    ),
    (
        "🏢",
        "Act 4 — The Solution",
        "The B.A.S.E. subsidy program: composite scoring across 3.1M businesses.",
    ),
    ("🎯", "Act 5 — The Impact", "Measurable targets: every agency gets a crime reduction goal."),
]

cols = st.columns(len(acts))
for col_obj, (icon, title, desc) in zip(cols, acts, strict=False):
    with col_obj:
        st.markdown(
            f"""
            <div style="
                background: #161B22;
                border: 1px solid #30363D;
                border-top: 3px solid #FF6B35;
                border-radius: 8px;
                padding: 16px;
                height: 140px;
            ">
                <div style="font-size: 1.5rem; margin-bottom: 8px;">{icon}</div>
                <div style="font-weight: 600; font-size: 0.85rem; color: #E6EDF3; margin-bottom: 6px;">{title}</div>
                <div style="font-size: 0.78rem; color: #8B949E;">{desc}</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

st.divider()

# ---------------------------------------------------------------------------
# AI + Semantic layer features
# ---------------------------------------------------------------------------

col_a, col_b = st.columns(2)

with col_a:
    st.markdown(
        """
        <div style="
            background: #161B22;
            border: 1px solid #30363D;
            border-radius: 10px;
            padding: 20px 24px;
        ">
            <div style="font-size: 1.4rem; margin-bottom: 8px;">💬</div>
            <div style="font-weight: 700; font-size: 1rem; color: #E6EDF3; margin-bottom: 8px;">
                Ask the Data
            </div>
            <div style="font-size: 0.85rem; color: #8B949E; line-height: 1.6;">
                Natural language querying powered by <strong style="color:#FF6B35">Snowflake Cortex Analyst</strong>.
                Ask any question about Colorado crime, income, or subsidies —
                the AI translates it to SQL grounded by your semantic model.
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

with col_b:
    st.markdown(
        """
        <div style="
            background: #161B22;
            border: 1px solid #30363D;
            border-radius: 10px;
            padding: 20px 24px;
        ">
            <div style="font-size: 1.4rem; margin-bottom: 8px;">🔮</div>
            <div style="font-weight: 700; font-size: 1rem; color: #E6EDF3; margin-bottom: 8px;">
                Semantic Layer
            </div>
            <div style="font-size: 0.85rem; color: #8B949E; line-height: 1.6;">
                Metrics defined once in <strong style="color:#FF6B35">dbt MetricFlow</strong> and
                materialized as Snowflake Semantic Views — powering dashboards,
                BI tools, and AI from a single source of truth.
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

st.divider()

# ---------------------------------------------------------------------------
# Tech stack footer
# ---------------------------------------------------------------------------

st.markdown(
    """
    <div style="color: #8B949E; font-size: 0.78rem; line-height: 2;">
        <strong style="color: #E6EDF3;">Pipeline:</strong>
        Apache Airflow (Astronomer) · AWS S3 · Snowflake · dbt-core · Terraform &nbsp;|&nbsp;
        <strong style="color: #E6EDF3;">Modeling:</strong>
        Kimball Star Schema · Medallion Architecture · SCD Type 2 · MetricFlow &nbsp;|&nbsp;
        <strong style="color: #E6EDF3;">Presentation:</strong>
        Streamlit · Plotly · Metabase · Snowflake Cortex Analyst
    </div>
    """,
    unsafe_allow_html=True,
)
