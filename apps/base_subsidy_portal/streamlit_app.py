"""
Colorado B.A.S.E. Subsidy Checker
Business Assistance for Security Enhancements — public lookup + OEDIT admin view.

Data source: COLORADO_CRIME_DB_PROD.GOLD.RPT_BUSINESS_TIER_LOOKUP
All data access goes through Snowpark (session.table / DataFrame API).
"""

import os

import streamlit as st
from snowflake.snowpark.functions import col, count, lit, upper
from snowflake.snowpark.types import StringType

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

TIER_TABLE = "COLORADO_CRIME_DB_PROD.GOLD.RPT_BUSINESS_TIER_LOOKUP"

# Columns surfaced to the public lookup UI. Snowflake column names are uppercase.
PUBLIC_COLUMNS = [
    "ENTITY_ID",
    "ENTITY_NAME",
    "PRINCIPAL_CITY",
    "PRINCIPAL_COUNTY",
    "PRINCIPAL_ZIP",
    "ENTITY_TYPE",
    "FORMATION_DATE",
    "COMPOSITE_TIER",
    "SUBSIDY_TIER_LABEL",
    "QUALIFIES_FOR_SUBSIDY",
    "SUBSIDY_MESSAGE",
]

# Cap name-search result sets so a broad search cannot pull back the whole table.
MAX_NAME_MATCHES = 100


# ---------------------------------------------------------------------------
# Page config + Snowpark session
# ---------------------------------------------------------------------------

st.set_page_config(
    page_title="Colorado B.A.S.E. Subsidy Checker",
    page_icon=":material/verified_user:",
    layout="wide",
)

# Streamlit in Snowflake (Workspace container runtime) supplies the Snowflake
# identity through st.connection; .session() hands back a Snowpark Session.
conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()


# ---------------------------------------------------------------------------
# Snowpark data access
# ---------------------------------------------------------------------------


def search_businesses(search_term: str):
    """
    Look up businesses by ENTITY_ID (exact match) or ENTITY_NAME (case-insensitive
    contains). Returns a Pandas DataFrame.

    ENTITY_ID is stored as a NUMBER in Snowflake, so it is cast to VARCHAR before
    comparison — that lets a single text box serve both search modes without the
    caller needing to know the underlying type.
    """
    term = search_term.strip()
    if not term:
        return None

    base = session.table(TIER_TABLE).select(*PUBLIC_COLUMNS)

    # Exact ID match first — an entity ID uniquely identifies one business.
    if term.isdigit():
        id_matches = base.filter(col("ENTITY_ID").cast(StringType()) == lit(term))
        results = id_matches.limit(MAX_NAME_MATCHES + 1).to_pandas()
        if not results.empty:
            return results

    # Fall back to a name search. Snowpark's Column has no ilike(), so fold both
    # sides to upper case and use like() for a case-insensitive "contains" match.
    # The search term is passed as a bound literal, never interpolated into SQL.
    name_matches = (
        base.filter(upper(col("ENTITY_NAME")).like(lit(f"%{term.upper()}%")))
        .sort(col("ENTITY_NAME").asc())
        .limit(MAX_NAME_MATCHES + 1)
    )
    return name_matches.to_pandas()


@st.cache_data(ttl="15m", show_spinner=False)
def load_eligible_total() -> int:
    """Total count of businesses flagged NOTIFICATION_ELIGIBLE."""
    eligible = session.table(TIER_TABLE).filter(col("NOTIFICATION_ELIGIBLE") == lit(True))
    return eligible.count()


@st.cache_data(ttl="15m", show_spinner=False)
def load_eligible_by_county():
    """
    Notification-eligible business counts grouped by PRINCIPAL_COUNTY.
    Cached as Pandas so the aggregation runs in Snowflake once per TTL window.
    """
    by_county = (
        session.table(TIER_TABLE)
        .filter(col("NOTIFICATION_ELIGIBLE") == lit(True))
        .filter(col("PRINCIPAL_COUNTY").is_not_null())
        .group_by(col("PRINCIPAL_COUNTY"))
        .agg(count(lit(1)).alias("ELIGIBLE_BUSINESSES"))
        .sort(col("ELIGIBLE_BUSINESSES").desc())
    )
    counts = by_county.to_pandas()
    # County values are stored lowercase in the source table; title-case for display.
    counts["PRINCIPAL_COUNTY"] = counts["PRINCIPAL_COUNTY"].str.title()
    return counts


@st.cache_data(ttl="15m", show_spinner=False)
def load_tier_breakdown():
    """Business counts per subsidy tier, for the admin overview."""
    by_tier = (
        session.table(TIER_TABLE)
        .group_by(col("COMPOSITE_TIER"), col("SUBSIDY_TIER_LABEL"))
        .agg(count(lit(1)).alias("BUSINESSES"))
        .sort(col("COMPOSITE_TIER").desc())
    )
    return by_tier.to_pandas()


def clear_admin_caches() -> None:
    """Drop memoized admin aggregates so grant officers can force a refresh."""
    load_eligible_total.clear()
    load_eligible_by_county.clear()
    load_tier_breakdown.clear()


# ---------------------------------------------------------------------------
# Rendering helpers
# ---------------------------------------------------------------------------


def render_single_result(row) -> None:
    """Render the detail card for one matched business."""
    st.subheader(row["ENTITY_NAME"])

    left, middle, right = st.columns(3)
    left.metric("City", row["PRINCIPAL_CITY"] or "—")
    middle.metric("County", row["PRINCIPAL_COUNTY"] or "—")
    right.metric("Entity ID", str(row["ENTITY_ID"]))

    detail_a, detail_b, detail_c = st.columns(3)
    detail_a.markdown(f"**Entity type**  \n{row['ENTITY_TYPE'] or '—'}")
    detail_b.markdown(f"**ZIP code**  \n{row['PRINCIPAL_ZIP'] or '—'}")
    detail_c.markdown(f"**Formation date**  \n{row['FORMATION_DATE'] or '—'}")

    st.divider()

    # Prominent tier label — this is the headline number for the business owner.
    qualifies = bool(row["QUALIFIES_FOR_SUBSIDY"])
    tier_label = row["SUBSIDY_TIER_LABEL"] or "Tier not assigned"
    tier_color = "green" if qualifies else "gray"
    st.markdown(f"### :{tier_color}[{tier_label}]")

    message = row["SUBSIDY_MESSAGE"] or "No eligibility message is available for this business."
    if qualifies:
        st.success(message, icon=":material/check_circle:")
    else:
        st.info(message, icon=":material/info:")

    if qualifies:
        st.caption(
            "Next step: contact the Colorado Office of Economic Development and "
            "International Trade (OEDIT) to begin your subsidy application. Have "
            "your entity ID ready."
        )


def render_public_lookup() -> None:
    """Section A — public-facing business lookup."""
    st.title("Colorado B.A.S.E. Subsidy Checker")
    st.markdown(
        "**Business Assistance for Security Enhancements (B.A.S.E.)** helps Colorado "
        "business owners offset the cost of security improvements. Enter your "
        "business name or Colorado Secretary of State entity ID below to see "
        "whether your business qualifies for a state security subsidy."
    )

    # A form batches the input so we do not query on every keystroke.
    with st.form("business_search"):
        search_term = st.text_input(
            "Business name or entity ID",
            placeholder="e.g. Mile High Hardware  or  20121234567",
            help="Entity IDs are matched exactly. Names are matched case-insensitively.",
        )
        submitted = st.form_submit_button("Search", type="primary")

    if not submitted:
        st.caption("Enter a business name or entity ID and select **Search** to begin.")
        return

    if not search_term.strip():
        st.warning("Please enter a business name or entity ID to search.")
        return

    with st.spinner("Searching Colorado business records..."):
        results = search_businesses(search_term)

    if results is None or results.empty:
        st.warning(
            "Business not found. Check the spelling of the business name, or try "
            "searching by your Colorado Secretary of State entity ID."
        )
        return

    truncated = len(results) > MAX_NAME_MATCHES
    if truncated:
        results = results.head(MAX_NAME_MATCHES)

    if len(results) == 1:
        render_single_result(results.iloc[0])
        return

    # Multiple name matches — let the user narrow it down themselves.
    st.info(
        f"Found {len(results)} matching businesses"
        + (f" (showing the first {MAX_NAME_MATCHES})" if truncated else "")
        + ". Search again using the exact entity ID for a full eligibility report."
    )
    st.dataframe(
        results[
            [
                "ENTITY_ID",
                "ENTITY_NAME",
                "PRINCIPAL_CITY",
                "PRINCIPAL_COUNTY",
                "ENTITY_TYPE",
                "SUBSIDY_TIER_LABEL",
                "QUALIFIES_FOR_SUBSIDY",
            ]
        ],
        width="stretch",
        hide_index=True,
        column_config={
            "ENTITY_ID": st.column_config.TextColumn("Entity ID"),
            "ENTITY_NAME": st.column_config.TextColumn("Business name"),
            "PRINCIPAL_CITY": st.column_config.TextColumn("City"),
            "PRINCIPAL_COUNTY": st.column_config.TextColumn("County"),
            "ENTITY_TYPE": st.column_config.TextColumn("Type"),
            "SUBSIDY_TIER_LABEL": st.column_config.TextColumn("Subsidy tier"),
            "QUALIFIES_FOR_SUBSIDY": st.column_config.CheckboxColumn("Qualifies"),
        },
    )


def render_admin_view() -> None:
    """Section B — aggregated view for OEDIT grant officers."""
    header, refresh = st.columns([4, 1], vertical_alignment="bottom")
    with header:
        st.title("OEDIT Admin")
        st.markdown(
            "Aggregated outreach view for grant officers. Counts reflect businesses "
            "that are active **and** qualify for a subsidy "
            "(`NOTIFICATION_ELIGIBLE`)."
        )
    with refresh:
        # Cached aggregates have a 15m TTL; this forces an immediate refresh.
        st.button(
            "Refresh data",
            icon=":material/refresh:",
            on_click=clear_admin_caches,
            width="stretch",
        )

    with st.spinner("Loading eligibility totals..."):
        eligible_total = load_eligible_total()
        county_counts = load_eligible_by_county()
        tier_counts = load_tier_breakdown()

    metric_a, metric_b, metric_c = st.columns(3)
    metric_a.metric("Notification-eligible businesses", f"{eligible_total:,}")
    metric_b.metric("Counties with eligible businesses", f"{len(county_counts):,}")
    top_county = county_counts.iloc[0]["PRINCIPAL_COUNTY"] if not county_counts.empty else "—"
    metric_c.metric("Highest-need county", top_county)

    st.divider()

    st.subheader("Eligible businesses by county")
    if county_counts.empty:
        st.info("No notification-eligible businesses found.")
    else:
        st.bar_chart(
            county_counts,
            x="PRINCIPAL_COUNTY",
            y="ELIGIBLE_BUSINESSES",
            x_label="County",
            y_label="Eligible businesses",
        )
        with st.expander("View county counts as a table"):
            st.dataframe(
                county_counts,
                width="stretch",
                hide_index=True,
                column_config={
                    "PRINCIPAL_COUNTY": st.column_config.TextColumn("County"),
                    "ELIGIBLE_BUSINESSES": st.column_config.NumberColumn(
                        "Eligible businesses", format="%d"
                    ),
                },
            )

    st.divider()

    st.subheader("Statewide tier distribution")
    if tier_counts.empty:
        st.info("No tier data available.")
    else:
        st.dataframe(
            tier_counts,
            width="stretch",
            hide_index=True,
            column_config={
                "COMPOSITE_TIER": st.column_config.NumberColumn("Tier", format="%d"),
                "SUBSIDY_TIER_LABEL": st.column_config.TextColumn("Label"),
                "BUSINESSES": st.column_config.NumberColumn("Businesses", format="%d"),
            },
        )


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

# on_change="rerun" makes the tabs dynamic so only the visible tab queries Snowflake.
public_tab, admin_tab = st.tabs(
    ["Subsidy Lookup", "OEDIT Admin"],
    on_change="rerun",
)

if public_tab.open is not False:
    with public_tab:
        render_public_lookup()

if admin_tab.open:
    with admin_tab:
        render_admin_view()
