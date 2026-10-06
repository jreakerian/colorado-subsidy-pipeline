"""
Page 4 — 🏢 The Solution

Act 4 of the B.A.S.E. data narrative.

"Acts 1–3 mapped the problem. Act 4 is the intervention:
 a composite scoring engine that ranks every Colorado business
 for security subsidy eligibility."

Tabs:
  A. Subsidy Lookup   — public-facing: search by entity ID or business name
  B. OEDIT Admin      — internal: eligible counts, tier distribution, county map
  C. Program Overview — analytics: how the scoring engine works (new)
"""

import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

from components.data_loaders import (
    get_session,
    load_eligible_by_county,
    load_eligible_total,
    load_headline_stats,
    load_tier_breakdown,
    search_businesses,
)
from components.styles import PALETTE, act_header, inject_css

# ── Page setup ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="The Solution · B.A.S.E. Portal",
    page_icon="🏢",
    layout="wide",
)
inject_css()
session = get_session()

# ── Act header ────────────────────────────────────────────────────────────────
act_header(
    4,
    "The Solution — B.A.S.E. Program",
    "Acts 1–3 mapped the problem. Act 4 is the intervention: a composite "
    "scoring engine that ranked every Colorado business for security subsidy "
    "eligibility — turning 9M crime incidents into 3.1M business decisions.",
)

# ── Program KPI banner ────────────────────────────────────────────────────────
with st.spinner("Loading program stats…"):
    try:
        stats = load_headline_stats(session)
        tier_df = load_tier_breakdown(session)

        c1, c2, c3 = st.columns(3)
        c1.metric("Businesses Scored", f"{stats['total_businesses']:,}")
        c2.metric(
            "Qualifying Businesses",
            f"{stats['qualifying_businesses']:,}",
            help="Good Standing or Exists entity status AND composite tier ≥ 3",
        )
        c3.metric(
            "Subsidy Tiers",
            "4",
            help="Tier 1 ($1K) → Tier 4 ($2.5K) annual subsidy",
        )
    except Exception as e:
        st.warning(f"Stats unavailable — check Snowflake connection. ({e})")

st.divider()

# ── Tabs ──────────────────────────────────────────────────────────────────────
tab_lookup, tab_admin, tab_overview = st.tabs(
    ["🔍 Subsidy Lookup", "📋 OEDIT Admin", "⚙️ Scoring Engine"],
    on_change="rerun",
)

# ══════════════════════════════════════════════════════════════════════════════
# TAB A — Public-Facing Subsidy Lookup
# (Preserved exactly from original app — logic unchanged)
# ══════════════════════════════════════════════════════════════════════════════

def _render_single_result(row) -> None:
    """Render the full eligibility card for a single matched business."""
    qualifies         = bool(row.get("QUALIFIES_FOR_SUBSIDY"))
    tier              = int(row.get("COMPOSITE_TIER", 0))
    entity_status     = row.get("ENTITY_STATUS", "")
    compliance_status = row.get("COMPLIANCE_STATUS", "Compliant")
    pending           = compliance_status == "Pending Compliance"
    message           = row.get("SUBSIDY_MESSAGE") or "No eligibility message available."

    # Card left-border: amber for pending compliance, tier colour otherwise
    TIER_COLORS_INLINE = {4: "#00C853", 3: "#2EA043", 2: "#8B949E", 1: "#30363D"}
    tier_color = "#D4A017" if pending else TIER_COLORS_INLINE.get(tier, "#30363D")

    # ── Business name card ────────────────────────────────────────────────────
    st.markdown(
        f"""
        <div style="
            background: #161B22;
            border: 1px solid #30363D;
            border-left: 4px solid {tier_color};
            border-radius: 8px;
            padding: 20px 24px;
            margin: 12px 0;
        ">
            <div style="font-size:0.75rem;color:#8B949E;text-transform:uppercase;letter-spacing:.08em;margin-bottom:4px;">Business</div>
            <div style="font-size:1.3rem;font-weight:700;color:#E6EDF3;">{row.get("ENTITY_NAME", "—")}</div>
            <div style="font-size:0.85rem;color:#8B949E;margin-top:4px;">
                Entity ID: {row.get("ENTITY_ID","—")} &nbsp;·&nbsp;
                {row.get("ENTITY_TYPE","—")} &nbsp;·&nbsp;
                {row.get("PRINCIPAL_CITY","—")}, {row.get("PRINCIPAL_COUNTY","—")} {row.get("PRINCIPAL_ZIP","") or ""}
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    # ── Subsidy message — sole qualifier/disqualifier statement ───────────────
    if pending:
        st.warning(message, icon=":material/warning:")
    elif qualifies:
        st.success(message, icon=":material/check_circle:")
    else:
        st.info(message, icon=":material/info:")

    st.markdown("---")

    # ── Metric cards: Composite Tier | Entity Status ──────────────────────────
    col_tier, col_compliance = st.columns(2)
    with col_tier:
        st.metric("Composite Tier", f"Tier {tier}" if tier else "—")
        st.caption(row.get("SUBSIDY_TIER_LABEL", ""))
    with col_compliance:
        st.metric(
            "Entity Status",
            entity_status or "—",
            help="Colorado Secretary of State registration status",
        )
        if pending:
            st.caption("⚠️ Pending Compliance")

    # ── Pending Compliance: action steps then stop ────────────────────────────
    if pending:
        st.markdown("---")
        st.warning(
            f"**To unlock your subsidy:** file your overdue periodic report (and pay "
            f"any outstanding fees) at "
            f"[sos.colorado.gov](https://www.sos.state.co.us/biz/). "
            f"Once your status returns to *Good Standing*, your Tier {tier} subsidy "
            f"will activate automatically at the next programme cycle.",
            icon=":material/info:",
        )
        return

    # ── Tier benefits (compliant businesses only) ─────────────────────────────
    st.markdown("---")
    st.markdown("**Tier Benefits**")

    tier_benefits = {
        1: {
            "amount": "$1,000",
            "benefits": [
                "$1,000 subsidy for security systems",
                "Discounted installation services",
                "Access to a directory of approved vendors",
                "Basic online support and troubleshooting",
                "Crime prevention best practices guide",
                "Marketing materials and B.A.S.E. badge",
            ],
        },
        2: {
            "amount": "$1,500",
            "benefits": [
                "$1,500 subsidy for security systems",
                "Free or subsidised installation",
                "One-time security system training session",
                "24/7 support and on-site repairs",
                "Extended warranty (1 year)",
                "Vendor discounts for third-party services",
                "Marketing and social media promotion",
                "Referral program for future subsidies",
            ],
        },
        3: {
            "amount": "$2,000",
            "benefits": [
                "$2,000 subsidy for security systems",
                "Free premium installation & consultations",
                "24/7 priority support",
                "Cybersecurity service discounts",
                "Free annual security audit",
                "Monitoring service discounts",
                "Extended warranty (2 years)",
                "Performance-based incentives",
            ],
        },
        4: {
            "amount": "$2,500",
            "benefits": [
                "$2,500 subsidy for security systems",
                "Full-service custom installations",
                "Premium 24/7 support with on-site assistance",
                "Comprehensive cybersecurity integration",
                "3-year extended warranty and maintenance",
                "Priority access to top-tier vendors",
                "Annual security reviews",
            ],
        },
    }

    if tier in tier_benefits:
        info = tier_benefits[tier]
        st.markdown(f"**Annual Subsidy:** {info['amount']}")
        for benefit in info["benefits"]:
            st.markdown(f"- {benefit}")

    if qualifies:
        st.caption(
            "Next step: contact the Colorado Office of Economic Development and "
            "International Trade (OEDIT) to begin your subsidy application. "
            "Have your entity ID ready."
        )



with tab_lookup:
    st.subheader("Colorado B.A.S.E. Subsidy Checker")
    st.markdown(
        "**Business Assistance for Security Enhancements (B.A.S.E.)** helps Colorado "
        "business owners offset the cost of security improvements. Enter your business "
        "name or Colorado Secretary of State entity ID to see your assigned tier."
    )

    with st.form("business_search"):
        search_term = st.text_input(
            "Business name or entity ID",
            placeholder="e.g.  Mile High Hardware   or   20121234567",
            help="Entity IDs are matched exactly. Names are matched case-insensitively.",
        )
        submitted = st.form_submit_button("Search", type="primary")

    if not submitted:
        st.caption("Enter a business name or entity ID and press **Search** to begin.")
    elif not search_term.strip():
        st.warning("Please enter a business name or entity ID to search.")
    else:
        with st.spinner("Searching Colorado business records…"):
            results = search_businesses(session, search_term)

        if results is None or results.empty:
            st.warning(
                "Business not found. Check the spelling of the business name, "
                "or try searching by your Colorado Secretary of State entity ID."
            )
        else:
            MAX_MATCHES = 100
            truncated = len(results) > MAX_MATCHES
            if truncated:
                results = results.head(MAX_MATCHES)

            if len(results) == 1:
                _render_single_result(results.iloc[0])
            else:
                st.info(
                    f"Found {len(results)} matching businesses"
                    + (f" (showing the first {MAX_MATCHES})" if truncated else "")
                    + ". Search again using the exact entity ID for a full eligibility report."
                )
                # Show available columns (entity_status/compliance_status present
                # after the dbt rebuild; fall back gracefully if not yet deployed)
                available = results.columns.tolist()
                display_cols = [
                    c for c in [
                        "ENTITY_ID", "ENTITY_NAME", "PRINCIPAL_CITY",
                        "PRINCIPAL_COUNTY", "ENTITY_TYPE", "ENTITY_STATUS",
                        "SUBSIDY_TIER_LABEL", "COMPLIANCE_STATUS", "QUALIFIES_FOR_SUBSIDY",
                    ] if c in available
                ]
                st.dataframe(
                    results[display_cols],
                    width="stretch",
                    hide_index=True,
                    column_config={
                        "ENTITY_ID":             st.column_config.TextColumn("Entity ID"),
                        "ENTITY_NAME":           st.column_config.TextColumn("Business Name"),
                        "PRINCIPAL_CITY":        st.column_config.TextColumn("City"),
                        "PRINCIPAL_COUNTY":      st.column_config.TextColumn("County"),
                        "ENTITY_TYPE":           st.column_config.TextColumn("Type"),
                        "ENTITY_STATUS":         st.column_config.TextColumn("CDOS Status"),
                        "SUBSIDY_TIER_LABEL":    st.column_config.TextColumn("Subsidy Tier"),
                        "COMPLIANCE_STATUS":     st.column_config.TextColumn("Compliance"),
                        "QUALIFIES_FOR_SUBSIDY": st.column_config.CheckboxColumn("Qualifies"),
                    },
                )

# ══════════════════════════════════════════════════════════════════════════════
# TAB B — OEDIT Admin
# (Original admin view preserved; charts upgraded from st.bar_chart to Plotly)
# ══════════════════════════════════════════════════════════════════════════════

with tab_admin:
    if tab_admin.open is not False:
        header_col, refresh_col = st.columns([4, 1], vertical_alignment="bottom")
        with header_col:
            st.subheader("OEDIT Admin — Notification Outreach View")
            st.markdown(
                "Aggregated outreach view for grant officers. Counts reflect businesses "
                "that are active **and** qualify for a subsidy (`NOTIFICATION_ELIGIBLE`)."
            )
        with refresh_col:
            if st.button("🔄 Refresh", width="stretch"):
                st.cache_data.clear()
                st.rerun()

        with st.spinner("Loading eligibility data…"):
            try:
                _eligible_total = load_eligible_total(session)
                _county_counts  = load_eligible_by_county(session)
                _tier_counts    = load_tier_breakdown(session)

                m1, m2, m3 = st.columns(3)
                m1.metric("Notification-Eligible Businesses", f"{_eligible_total:,}")
                m2.metric("Counties with Eligible Businesses", f"{len(_county_counts):,}")
                top_county = _county_counts.iloc[0]["PRINCIPAL_COUNTY"] if not _county_counts.empty else "—"
                m3.metric("Highest-Need County", top_county)

                st.divider()
                st.subheader("Eligible Businesses by County — Top 30")

                if not _county_counts.empty:
                    df_county_plot = (
                        _county_counts
                        .nlargest(30, "ELIGIBLE_BUSINESSES")
                        .sort_values("ELIGIBLE_BUSINESSES", ascending=True)
                    )
                    fig_county = go.Figure(
                        go.Bar(
                            x=df_county_plot["ELIGIBLE_BUSINESSES"],
                            y=df_county_plot["PRINCIPAL_COUNTY"],
                            orientation="h",
                            marker_color=PALETTE["primary"],
                            text=df_county_plot["ELIGIBLE_BUSINESSES"],
                            texttemplate="%{x:,}",
                            textposition="outside",
                            hovertemplate="<b>%{y}</b>: %{x:,} eligible<extra></extra>",
                        )
                    )
                    fig_county.update_layout(
                        height=560,
                        xaxis=dict(title="Eligible Businesses"),
                        yaxis=dict(showgrid=False),
                        margin=dict(l=120, r=60, t=20, b=20),
                    )
                    st.plotly_chart(fig_county, width="stretch")

                    with st.expander("View all counties as a table"):
                        st.dataframe(
                            _county_counts,
                            width="stretch",
                            hide_index=True,
                            column_config={
                                "PRINCIPAL_COUNTY":    st.column_config.TextColumn("County"),
                                "ELIGIBLE_BUSINESSES": st.column_config.NumberColumn("Eligible Businesses", format="%d"),
                            },
                        )

                st.divider()
                st.subheader("Statewide Tier Distribution")

                if not _tier_counts.empty:
                    tier_label_map = {
                        4: "Tier 4 — Maximum ($2,500)",
                        3: "Tier 3 — Enhanced ($2,000)",
                        2: "Tier 2 — Standard ($1,500)",
                        1: "Tier 1 — Basic ($1,000)",
                    }
                    tier_color_map = {
                        4: PALETTE["tier_4"],
                        3: PALETTE["tier_3"],
                        2: PALETTE["tier_2"],
                        1: PALETTE["tier_1"],
                    }
                    _tier_counts["TIER_LABEL_DISPLAY"] = _tier_counts["COMPOSITE_TIER"].map(tier_label_map)
                    _tier_counts["TIER_COLOR"] = _tier_counts["COMPOSITE_TIER"].map(tier_color_map)

                    fig_donut = go.Figure(
                        go.Pie(
                            labels=_tier_counts["TIER_LABEL_DISPLAY"],
                            values=_tier_counts["BUSINESSES"],
                            hole=0.58,
                            marker=dict(colors=_tier_counts["TIER_COLOR"].tolist()),
                            textinfo="percent+label",
                            textfont=dict(size=12),
                            hovertemplate="<b>%{label}</b><br>%{value:,} businesses (%{percent})<extra></extra>",
                        )
                    )
                    fig_donut.update_layout(
                        height=360,
                        showlegend=True,
                        legend=dict(orientation="v", x=1.02, y=0.5),
                        annotations=[dict(
                            text=f"{_tier_counts['BUSINESSES'].sum():,}<br><span style='font-size:12px'>businesses</span>",
                            x=0.5, y=0.5,
                            font=dict(size=18, color=PALETTE["text"]),
                            showarrow=False,
                        )],
                    )
                    st.plotly_chart(fig_donut, width="stretch")

                    with st.expander("View tier counts as a table"):
                        st.dataframe(
                            _tier_counts[["COMPOSITE_TIER", "SUBSIDY_TIER_LABEL", "BUSINESSES"]],
                            width="stretch",
                            hide_index=True,
                            column_config={
                                "COMPOSITE_TIER":    st.column_config.NumberColumn("Tier", format="%d"),
                                "SUBSIDY_TIER_LABEL": st.column_config.TextColumn("Label"),
                                "BUSINESSES":        st.column_config.NumberColumn("Businesses", format="%d"),
                            },
                        )
            except Exception as e:
                st.error(f"Error loading admin data: {e}")

# ══════════════════════════════════════════════════════════════════════════════
# TAB C — Scoring Engine explainer
# ══════════════════════════════════════════════════════════════════════════════

with tab_overview:
    st.subheader("How the B.A.S.E. Composite Score Works")
    st.markdown(
        "Each business is assigned a **Composite Tier (1–4)** from three independent "
        "sub-scores. This tab explains the scoring logic — ideal for a portfolio walkthrough."
    )

    col_a, col_b, col_c = st.columns(3)
    with col_a:
        st.markdown(
            """
            <div style="background:#161B22;border:1px solid #30363D;border-top:3px solid #FF6B35;border-radius:8px;padding:16px;">
                <div style="font-weight:700;font-size:0.95rem;color:#E6EDF3;margin-bottom:8px;">🔴 Crime Tier</div>
                <div style="font-size:0.82rem;color:#8B949E;line-height:1.7;">
                    Derived from the county's <strong>crime rate per 100K</strong> 
                    from <code>fct_crimes</code> × <code>dim_geography</code>.<br><br>
                    Quartile rank across all 64 counties →
                    Tier 1 (lowest crime) to Tier 4 (highest crime).
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with col_b:
        st.markdown(
            """
            <div style="background:#161B22;border:1px solid #30363D;border-top:3px solid #4C9BE8;border-radius:8px;padding:16px;">
                <div style="font-weight:700;font-size:0.95rem;color:#E6EDF3;margin-bottom:8px;">🔵 Income Tier</div>
                <div style="font-size:0.82rem;color:#8B949E;line-height:1.7;">
                    Derived from the county's <strong>median household income</strong>
                    from <code>fct_income_population</code>.<br><br>
                    Inverse quartile rank → lowest income counties receive Tier 4 
                    (highest subsidy need).
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with col_c:
        st.markdown(
            """
            <div style="background:#161B22;border:1px solid #30363D;border-top:3px solid #2EA043;border-radius:8px;padding:16px;">
                <div style="font-weight:700;font-size:0.95rem;color:#E6EDF3;margin-bottom:8px;">🟢 Population Tier</div>
                <div style="font-size:0.82rem;color:#8B949E;line-height:1.7;">
                    Derived from the county's <strong>population growth rate</strong>
                    from <code>fct_income_population</code>.<br><br>
                    High-growth counties face compounding infrastructure pressure →
                    higher tier assignment.
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    st.markdown("<br>", unsafe_allow_html=True)

    st.markdown(
        """
        <div style="
            background:#161B22;border:1px solid #FF6B35;border-radius:8px;
            padding:18px 24px;margin-top:8px;
        ">
            <div style="font-weight:700;font-size:1rem;color:#FF6B35;margin-bottom:8px;">Composite Formula</div>
            <div style="font-family:monospace;font-size:0.95rem;color:#E6EDF3;line-height:2;">
                composite_tier = ROUND( (crime_tier × 0.5) + (income_tier × 0.3) + (population_tier × 0.2) )<br>
                Clamped to [1, 4] &nbsp;·&nbsp; Computed in <code>fct_business_subsidy_tiers</code><br>
                Joined to <code>rpt_business_tier_lookup</code> for public-facing search
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    st.divider()

    st.subheader("Data Pipeline")
    st.markdown(
        """
        ```
        Raw Sources                  Snowflake Medallion              Streamlit
        ──────────────────           ─────────────────────────        ──────────────────────
        CDPS Crime (2001–2020)  →    Bronze (raw)                →    Page 1: Choropleth map
        NIBRS Crime (1997–2009) →    Silver (cleaned + unified)  →    Page 2: Seasonal heatmap
        ACS Census Income       →    Gold  (star schema marts)   →    Page 3: Disparity scatter
        CO SOS Business List    →                                →    Page 4: B.A.S.E. Lookup  ← you are here
        ```
        """
    )

# ── Navigation ────────────────────────────────────────────────────────────────
st.divider()
col_nav1, col_nav2 = st.columns(2)
col_nav1.page_link("pages/3_💰_The_Disparity.py", label="← The Disparity", icon="💰")
col_nav2.page_link("pages/5_🎯_The_Impact.py", label="Next: The Impact →", icon="🎯")
