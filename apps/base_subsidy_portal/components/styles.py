"""
styles.py — Design system for the B.A.S.E. Analytics Portal.

Defines:
  - Color palette (used by Plotly, narrative badges, tier colors)
  - Plotly figure template (applied to every chart)
  - CSS injection (via st.markdown) for typography, cards, KPI metrics

Usage:
    from components.styles import inject_css, PLOTLY_TEMPLATE, PALETTE
"""

import plotly.graph_objects as go
import plotly.io as pio
import streamlit as st

# ---------------------------------------------------------------------------
# Color Palette
# ---------------------------------------------------------------------------

PALETTE = {
    # Brand
    "primary": "#FF6B35",  # Orange — accent, highlights, CTAs
    "primary_light": "#FF8C5A",
    "primary_dark": "#CC4A1A",
    # Backgrounds (match config.toml)
    "bg": "#0D1117",  # Page background
    "bg_card": "#161B22",  # Card / secondary background
    "bg_border": "#30363D",  # Subtle borders
    # Text
    "text": "#E6EDF3",  # Primary text
    "text_muted": "#8B949E",  # Secondary / caption text
    # Crime-against categories (Property, Person, Society)
    "property": "#4C9BE8",  # Blue
    "person": "#FF6B35",  # Orange
    "society": "#7B68EE",  # Purple
    # Seasons
    "winter": "#4C9BE8",
    "spring": "#2EA043",
    "summer": "#FF6B35",
    "fall": "#D4A017",
    # Subsidy tiers
    "tier_4": "#00C853",  # Maximum — green
    "tier_3": "#2EA043",  # Enhanced — mid green
    "tier_2": "#8B949E",  # Standard — gray
    "tier_1": "#30363D",  # Basic — dark gray
    # Sequential scale for choropleth / heatmaps (light → dark orange)
    "scale": [
        [0.0, "#161B22"],
        [0.25, "#4A2008"],
        [0.5, "#8C3A12"],
        [0.75, "#CC4A1A"],
        [1.0, "#FF6B35"],
    ],
}

# Discrete color sequences for categorical charts
CRIME_AGAINST_COLORS = {
    "Property": PALETTE["property"],
    "Person": PALETTE["person"],
    "Society": PALETTE["society"],
}

TIER_COLORS = {
    "Tier 4 — Maximum Security Subsidy": PALETTE["tier_4"],
    "Tier 3 — Enhanced Security Subsidy": PALETTE["tier_3"],
    "Tier 2 — Standard Security Subsidy": PALETTE["tier_2"],
    "Tier 1 — Basic Security Review": PALETTE["tier_1"],
}

# ---------------------------------------------------------------------------
# Plotly Template
# ---------------------------------------------------------------------------


def _build_plotly_template() -> go.layout.Template:
    """Build and register a custom Plotly template matching the dark theme."""
    template = go.layout.Template()

    template.layout = go.Layout(
        paper_bgcolor=PALETTE["bg_card"],
        plot_bgcolor=PALETTE["bg_card"],
        font=dict(family="Inter, Arial, sans-serif", color=PALETTE["text"], size=13),
        title=dict(
            font=dict(size=18, color=PALETTE["text"], weight="bold"),
            x=0,
            pad=dict(l=4),
        ),
        xaxis=dict(
            gridcolor=PALETTE["bg_border"],
            zerolinecolor=PALETTE["bg_border"],
            tickfont=dict(color=PALETTE["text_muted"]),
            title_font=dict(color=PALETTE["text_muted"]),
        ),
        yaxis=dict(
            gridcolor=PALETTE["bg_border"],
            zerolinecolor=PALETTE["bg_border"],
            tickfont=dict(color=PALETTE["text_muted"]),
            title_font=dict(color=PALETTE["text_muted"]),
        ),
        legend=dict(
            bgcolor=PALETTE["bg"],
            bordercolor=PALETTE["bg_border"],
            borderwidth=1,
            font=dict(color=PALETTE["text_muted"]),
        ),
        margin=dict(l=24, r=24, t=48, b=24),
        hoverlabel=dict(
            bgcolor=PALETTE["bg"],
            bordercolor=PALETTE["bg_border"],
            font=dict(color=PALETTE["text"]),
        ),
        colorway=[
            PALETTE["primary"],
            PALETTE["property"],
            PALETTE["society"],
            "#2EA043",
            "#D4A017",
            "#F85149",
            "#58A6FF",
        ],
    )
    return template


# Register the template once at import time
PLOTLY_TEMPLATE = "base_dark"
pio.templates[PLOTLY_TEMPLATE] = _build_plotly_template()
pio.templates.default = PLOTLY_TEMPLATE


# ---------------------------------------------------------------------------
# CSS Injection
# ---------------------------------------------------------------------------

_CSS = """
<style>
/* ── Google Font ───────────────────────────────────────────────────── */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

html, body, [class*="css"] {
    font-family: 'Inter', sans-serif;
}

/* ── KPI metric cards ──────────────────────────────────────────────── */
[data-testid="metric-container"] {
    background-color: #161B22;
    border: 1px solid #30363D;
    border-radius: 10px;
    padding: 16px 20px;
}
[data-testid="metric-container"] label {
    color: #8B949E !important;
    font-size: 0.75rem !important;
    font-weight: 600 !important;
    text-transform: uppercase;
    letter-spacing: 0.08em;
}
[data-testid="metric-container"] [data-testid="stMetricValue"] {
    font-size: 2rem !important;
    font-weight: 700 !important;
    color: #E6EDF3 !important;
}

/* ── Narrative callout blocks ──────────────────────────────────────── */
.narrative-hook {
    border-left: 3px solid #FF6B35;
    padding: 12px 20px;
    background: #161B22;
    border-radius: 0 8px 8px 0;
    margin: 16px 0;
    color: #E6EDF3;
    font-size: 1.05rem;
    font-style: italic;
}

/* ── Act header badge ──────────────────────────────────────────────── */
.act-badge {
    display: inline-block;
    background: #FF6B35;
    color: #0D1117;
    font-size: 0.7rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    padding: 3px 10px;
    border-radius: 4px;
    margin-bottom: 8px;
}

/* ── Sidebar nav ───────────────────────────────────────────────────── */
[data-testid="stSidebarNav"] a {
    border-radius: 6px;
    padding: 6px 10px;
    transition: background 0.15s;
}
[data-testid="stSidebarNav"] a:hover {
    background: #30363D;
}

/* ── Dividers ──────────────────────────────────────────────────────── */
hr {
    border-color: #30363D !important;
}

/* ── Plotly chart container ────────────────────────────────────────── */
.stPlotlyChart {
    border-radius: 10px;
    overflow: hidden;
}

/* ── Chat messages ─────────────────────────────────────────────────── */
[data-testid="stChatMessage"] {
    border-radius: 10px;
    padding: 4px 8px;
}
</style>
"""


def inject_css() -> None:
    """Inject global CSS into the current page. Call once per page at the top."""
    st.markdown(_CSS, unsafe_allow_html=True)


# ---------------------------------------------------------------------------
# Narrative helpers
# ---------------------------------------------------------------------------


def act_header(act_num: int, act_title: str, hook: str) -> None:
    """Render a standardised Act header with badge + narrative hook."""
    st.markdown(f'<div class="act-badge">Act {act_num}</div>', unsafe_allow_html=True)
    st.title(act_title)
    st.markdown(f'<div class="narrative-hook">{hook}</div>', unsafe_allow_html=True)
