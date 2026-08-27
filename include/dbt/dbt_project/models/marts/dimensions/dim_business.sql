{{
  config(
    materialized = 'table',
    schema       = 'gold',
    tags         = ['marts', 'dimension', 'scd2'],

    {# Full-table rebuild on schedule; no incremental needed — the snapshot
       already handles the append-only SCD2 accumulation and physical ordering.
       dim_business is a clean denormalized view over that ordered snapshot. #}
    meta = {
      'owner'      : 'analytics',
      'tier'       : 'marts',
      'scd_type'   : 2,
      'pii'        : true,
      'pii_columns': ['entity_name', 'principal_address_1'],
      'description': 'SCD Type 2 Colorado business entity dimension. One row per entity per version of its mutable attributes. Use is_current = TRUE to get the present-day state. Use valid_from / valid_to for point-in-time subsidy eligibility audits.'
    }
  )
}}

-- ── Macros ─────────────────────────────────────────────────────────────────────
-- Centralise the zip validation pattern so it is defined once and referenced
-- twice (clean_zip_code column + city_county_zip join predicate).
{%- set zip_regex = '^\\d{5}(-\\d{4})?$' -%}

with

-- Pull every historical version of each business entity from the SCD2 snapshot.

snapshot as (

    select
        dbt_scd_id, -- dbt_scd_id is the unique surrogate key that identifies a specific version row.
        entity_id,
        entity_name,
        entity_status,
        entity_type,
        entity_form_date,
        jurisdiction_of_formation,
        principal_address_1,
        principal_city,
        principal_state,
        principal_zip_code,
        dbt_valid_from, -- dbt_valid_from / dbt_valid_to bound the period in which that version was active.
        dbt_valid_to,
        -- Derived columns computed once here rather than repeated downstream
        dbt_valid_to is null                                        as is_current, -- dbt_valid_to IS NULL means the record is the current live version.
        entity_status = 'Good Standing'                             as is_eligible,
        case
            when regexp_like(principal_zip_code, '{{ zip_regex }}')
                then substring(principal_zip_code, 1, 5)
            else null
        end                                                         as clean_zip_code
    from {{ ref('snapshot_colorado_business_entities') }}

),

-- Resolve the authoritative county from the ZIP+city seed.
-- This join is intentionally LEFT so businesses with missing/invalid ZIP codes
-- are still included — they simply get null resolved_county and are filtered
-- out only in subsidy eligibility queries downstream, not here.
geo_lookup as (

    select
        cast(zip_code as varchar) as zip_code,
        lower(trim(city))         as city,
        lower(trim(county))       as county
    from {{ ref('colorado_city_county_zip') }}

),

-- Enrich each snapshot version with resolved geography
enriched as (

    select
        s.dbt_scd_id,
        s.entity_id,
        s.entity_name,
        s.entity_status,
        s.entity_type,
        s.entity_form_date,
        s.jurisdiction_of_formation,
        s.principal_address_1,
        s.principal_city,
        s.principal_state,
        s.clean_zip_code,

        -- County resolution priority:
        --   1. ZIP lookup  → most reliable, ties the business to a specific county
        --   2. State field → last-resort fallback when ZIP is missing/invalid
        coalesce(g.county, lower(trim(s.principal_state)))          as resolved_county,

        -- Prefer the lookup city (normalized) over the raw API city name to
        -- avoid county mismatches from typos in the source (e.g. "DENVERL")
        coalesce(g.city, lower(trim(s.principal_city)))             as resolved_city,

        -- SCD2 temporal metadata
        s.dbt_valid_from                                            as valid_from,
        s.dbt_valid_to                                              as valid_to,
        s.is_current,
        s.is_eligible

    from snapshot s
    left join geo_lookup g
        on s.clean_zip_code = g.zip_code

),

-- Stable surrogate key 
-- Use md5(entity_id || '::' || valid_from) rather than row_number() over (order by
-- entity_id) — the previous approach.
--
-- Why md5 is strictly better here:
--   row_number() is non-deterministic across dbt full-table rebuilds if the
--   underlying row count or ordering changes (e.g., late-arriving data). This
--   silently breaks FK relationships in fct_business_subsidy_tiers because the
--   same physical business would receive a *different* business_key each rebuild.
--
--   md5(entity_id || '::' || valid_from::varchar) is stable and reproducible:
--   the same entity version always produces the same key regardless of rebuild
--   timing or order.

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['entity_id', 'valid_from']) }}
                                                                    as business_key,
        dbt_scd_id                                                  as business_scd_id,
        entity_id,
        entity_name,
        principal_address_1,
        resolved_city                                               as principal_city,
        resolved_county                                             as principal_county,
        principal_state,
        clean_zip_code                                              as principal_zip,
        entity_status,
        entity_type,
        entity_form_date                                            as formation_date,
        jurisdiction_of_formation                                   as jurisdiction,
        is_eligible,
        is_current,
        valid_from,
        valid_to,

        -- Pipeline audit: when was this version of the row last refreshed in the DW
        current_timestamp()                                         as dw_updated_at

    from enriched

)

-- ORDER BY mirrors the columns previously in cluster_by: ['is_current', 'entity_status'].
-- Because dim_business is a full table rebuild on every dbt run, this ORDER BY physically
-- writes micro-partitions in the most common query access order at build time — at zero
-- ongoing compute cost. Snowflake's micro-partition pruning then benefits the same queries
-- that cluster_by would have served:
--   1. is_current DESC  → current rows land in the first micro-partitions
--                         (subsidy portal queries: WHERE is_current = true)
--   2. entity_status    → groups eligibility within current rows
--                         (eligibility filter: AND entity_status = 'Good Standing')
--   3. entity_id        → deterministic tie-break; stable sort across rebuilds
--
-- is_current cannot be sorted in the snapshot source query (dbt_valid_to is appended
-- by dbt after the source SELECT runs and the snapshot appends rows incrementally,
-- so sort order would drift). The full-rebuild nature of this model is what makes
-- the ORDER BY effective here.
select * from final
order by
    is_current desc,
    entity_status,
    entity_id