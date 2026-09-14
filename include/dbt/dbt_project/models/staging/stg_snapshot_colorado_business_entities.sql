{{
  config(
    materialized='view',
    tags=['staging', 'bronze'],
    docs={'node_color': 'purple'}
  )
}}

-- ── stg_snapshot_colorado_business_entities ─────────────────────────────────────
-- Thin staging layer over the snapshot_colorado_business_entities snapshot.
--
-- Why this exists:
--   Snapshots, like seeds, are part of the raw/snapshot layer. Marts must not
--   reference them directly. This staging model acts as the single, documented
--   contract between the raw snapshot output and the dim_business mart model.
--
-- What this model does NOT do:
--   - It does not perform complex transformations (those belong in dim_business).
--   - It does not filter rows (SCD2 rows are preserved in full).
--   - It exposes all snapshot columns plus dbt's internal SCD2 metadata
--     columns (dbt_scd_id, dbt_valid_from, dbt_valid_to) so dim_business can
--     apply SCD2 logic against a stable, typed interface.
--
-- Note on snapshot column types:
--   dbt appends dbt_valid_from / dbt_valid_to as TIMESTAMP_LTZ. These are
--   passed through here without casting to preserve the exact type that dbt
--   produces, ensuring dim_business contracts remain stable.

with source as (
    select * from {{ ref('snapshot_colorado_business_entities') }}
),

renamed as (
    select
        -- dbt SCD2 metadata
        dbt_scd_id,
        dbt_valid_from,
        dbt_valid_to,

        -- Business entity fields
        entity_id,
        entity_name,
        entity_status,
        entity_type,
        entity_form_date,
        jurisdiction_of_formation,
        principal_address_1,
        principal_city,
        principal_state,
        principal_zip_code
    from source
)

select * from renamed
