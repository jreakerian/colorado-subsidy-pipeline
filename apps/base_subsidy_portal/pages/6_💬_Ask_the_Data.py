"""
Page 6 — 💬 Ask the Data

Cortex Analyst chat interface for the B.A.S.E. Analytics Portal.

Powered by Snowflake Cortex Analyst + a semantic model grounded in:
  - RPT_CITY_TIME_TRENDS         (seasonal/weekly crime patterns)
  - RPT_CITY_CRIME_DEMOGRAPHICS  (offense types, offender age)
  - RPT_COUNTY_AGENCY_CRIME_BASELINE (agency baselines + 5% targets)
  - RPT_BUSINESS_TIER_LOOKUP     (B.A.S.E. subsidy eligibility)

Features:
  - Multi-turn conversation with history
  - Auto-rendered charts for tabular results
  - SQL reveal (expander) — shows the generated SQL for credibility
  - 12 suggested questions for portfolio demonstrations
"""

import streamlit as st
from components.cortex import (
    ask_cortex_analyst,
    auto_chart,
    execute_analyst_sql,
    parse_analyst_response,
)
from components.data_loaders import get_session
from components.styles import inject_css

# ── Page setup ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Ask the Data · B.A.S.E. Portal",
    page_icon="💬",
    layout="wide",
)
inject_css()
session = get_session()

# ── Header ────────────────────────────────────────────────────────────────────
st.markdown(
    '<div class="act-badge">Cortex Analyst · Snowflake AI</div>',
    unsafe_allow_html=True,
)
st.title("💬 Ask the Data")
st.markdown(
    "Ask any question about Colorado crime, business subsidies, or agency targets "
    "in plain English. **Snowflake Cortex Analyst** translates it to SQL using "
    "a governed semantic model — no SQL knowledge required."
)


# ── Sidebar: model info + suggested questions ─────────────────────────────────
with st.sidebar:
    st.markdown("### 🗂️ Semantic Model")
    st.markdown(
        """
        Cortex Analyst is grounded by a YAML semantic model that defines
        4 tables, their dimensions, measures, and 12 verified example queries.

        **Tables covered:**
        - 🏙️ City Crime Patterns
        - 👤 City Crime Demographics
        - 🚔 Agency Crime Baselines
        - 🏢 Business Subsidy Tiers
        """
    )
    st.divider()

    st.markdown("### 💡 Try These Questions")
    suggested = [
        "Which cities have the most crimes?",
        "What season has the most crimes?",
        "Which day of the week is most dangerous?",
        "What are the most common types of crimes?",
        "Which county has the most crimes?",
        "How many crimes could be prevented if every agency hits its 5% target?",
        "How many businesses qualify for a subsidy in Denver?",
        "How many businesses are in the highest subsidy tier?",
        "Are there more crimes on weekends or weekdays?",
        "Which police agencies handle the most crimes?",
        "Which cities have the most property crimes?",
        "What is the average offender age for assault crimes?",
    ]

    for q in suggested:
        if st.button(q, key=f"suggest_{hash(q)}", width="stretch"):
            st.session_state["pending_question"] = q

    st.divider()
    if st.button("🗑️ Clear conversation", width="stretch"):
        st.session_state["messages"] = []
        st.session_state.pop("pending_question", None)
        st.rerun()

# ── Session state ─────────────────────────────────────────────────────────────
if "messages" not in st.session_state:
    st.session_state["messages"] = []

# ── Render existing conversation ───────────────────────────────────────────────
for msg in st.session_state["messages"]:
    role = msg["role"]
    with st.chat_message(role, avatar="🧑" if role == "user" else "❄️"):
        # User turn: just show the question
        if role == "user":
            st.markdown(msg["content"])

        # Analyst turn: text + optional SQL + optional chart/table
        else:
            if msg.get("text"):
                st.markdown(msg["text"])

            if msg.get("sql"):
                with st.expander("🔍 View generated SQL", expanded=False):
                    st.code(msg["sql"], language="sql")

            if msg.get("dataframe") is not None:
                df = msg["dataframe"]
                if not df.empty:
                    charted = auto_chart(df, title="")
                    if not charted:
                        st.dataframe(df, width="stretch", hide_index=True)
                    st.caption(f"↳ {len(df):,} row{'s' if len(df) != 1 else ''} returned")

            if msg.get("warnings"):
                with st.expander("i Model notes", expanded=False):
                    for w in msg["warnings"]:
                        st.caption(w)

            if msg.get("error"):
                st.error(msg["error"])

# ── Handle a pending question from sidebar buttons ────────────────────────────
pending = st.session_state.pop("pending_question", None)

# ── Chat input ────────────────────────────────────────────────────────────────
user_input = st.chat_input(
    "Ask a question about Colorado crime or the B.A.S.E. program…",
    key="chat_input",
)

question = pending or user_input

if question:
    # Show the user's message immediately
    with st.chat_message("user", avatar="🧑"):
        st.markdown(question)

    # Append to history (display only — content string)
    st.session_state["messages"].append(
        {
            "role": "user",
            "content": question,
        }
    )

    # Build Cortex conversation history (API format)
    cortex_history: list[dict] = []
    for m in st.session_state["messages"][:-1]:  # all but the just-added question
        if m["role"] == "user":
            cortex_history.append(
                {
                    "role": "user",
                    "content": [{"type": "text", "text": m["content"]}],
                }
            )
        elif m["role"] == "analyst" and m.get("text"):
            content_blocks = [{"type": "text", "text": m["text"]}]
            if m.get("sql"):
                content_blocks.append({"type": "sql", "statement": m["sql"]})
            cortex_history.append(
                {
                    "role": "analyst",
                    "content": content_blocks,
                }
            )

    # Call Cortex Analyst
    with st.chat_message("analyst", avatar="❄️"):
        with st.spinner("Cortex Analyst is thinking…"):
            raw_response = ask_cortex_analyst(
                session=session,
                question=question,
                conversation_history=cortex_history,
            )

        parsed = parse_analyst_response(raw_response)

        analyst_record: dict = {
            "role": "analyst",
            "text": parsed["text"],
            "sql": parsed["sql"],
            "warnings": parsed["warnings"],
            "error": parsed["error"],
            "dataframe": None,
        }

        # Render text
        if parsed["text"]:
            st.markdown(parsed["text"])

        # Render SQL expander
        if parsed["sql"]:
            with st.expander("🔍 View generated SQL", expanded=False):
                st.code(parsed["sql"], language="sql")

            # Execute SQL and render result
            with st.spinner("Running query on Snowflake…"):
                df_result = execute_analyst_sql(session, parsed["sql"])
                analyst_record["dataframe"] = df_result

            if df_result is not None and not df_result.empty:
                charted = auto_chart(df_result)
                if not charted:
                    st.dataframe(df_result, width="stretch", hide_index=True)
                st.caption(f"↳ {len(df_result):,} row{'s' if len(df_result) != 1 else ''} returned")
            elif df_result is not None:
                st.info("The query returned no results.")

        # Warnings — tucked away, not shown inline
        if parsed["warnings"]:
            with st.expander("i Model notes", expanded=False):
                for w in parsed["warnings"]:
                    st.caption(w)

        # Render error
        if parsed["error"]:
            st.error(parsed["error"])

    # Persist the analyst turn
    st.session_state["messages"].append(analyst_record)

# ── Empty state ───────────────────────────────────────────────────────────────
if not st.session_state["messages"]:
    st.markdown(
        """
        <div style="
            text-align: center;
            padding: 60px 40px;
            color: #8B949E;
        ">
            <div style="font-size: 3rem; margin-bottom: 16px;">❄️</div>
            <div style="font-size: 1.1rem; font-weight: 600; color: #E6EDF3; margin-bottom: 8px;">
                Cortex Analyst is ready
            </div>
            <div style="font-size: 0.9rem; line-height: 1.8;">
                Type a question in the box below, or pick one from the<br>
                <strong>suggested questions</strong> in the sidebar to get started.
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

# ── Navigation ────────────────────────────────────────────────────────────────
st.divider()
col_nav1, col_nav2 = st.columns(2)
col_nav1.page_link("pages/5_🎯_The_Impact.py", label="← The Impact", icon="🎯")
col_nav2.page_link("pages/7_🔮_Semantic_Layer.py", label="Next: Semantic Layer →", icon="🔮")
