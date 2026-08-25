{% snapshot snapshot_colorado_business_entities %}

{{
    config(
        -- ── Target ─────────────────────────────────────────────────────────────
        -- Write into the SILVER schema alongside other intermediates rather than
        -- a dedicated 'snapshots' schema so the same TRANSFORMER_ROLE grants apply
        -- without extra Terraform provisioning.
        target_schema  = 'silver',
        target_database = env_var('DBT_DATABASE', 'COLORADO_CRIME_DB_DEV'),

        -- ── Key & Strategy ─────────────────────────────────────────────────────
        -- `entity_id` is the stable natural key assigned by the Colorado SoS.
        -- It never changes for the life of a business registration, making it
        -- the correct unique_key — not a surrogate integer that could shift.
        unique_key     = 'entity_id',

        -- Strategy: 'check' over a narrow column list rather than 'timestamp'
        -- because the source API does not expose a reliable updated_at field.
        -- Only the columns that drive B.A.S.E. subsidy eligibility decisions
        -- are tracked — not cosmetic fields (address2, country) that generate
        -- false positives and inflate snapshot history without business value.
        strategy       = 'check',
        check_cols     = [
            'entity_status',          -- drives is_eligible: Good Standing ↔ Delinquent/Dissolved
            'principal_zip_code',     -- determines county, which determines subsidy tier
            'principal_city',         -- city change may cross county boundaries
            'entity_name',            -- name change could indicate corporate restructuring
            'entity_type',            -- e.g. LLC → Corp can affect subsidy classification
        ],

        -- Soft-delete invalidated rows when a business disappears from the
        -- source API entirely (dissolved/removed from registry).
        -- dbt_valid_to is set to the current timestamp; is_current becomes false.
        invalidate_hard_deletes = true,
    )
}}

-- ── Source selection ────────────────────────────────────────────────────────────
-- Read directly from the bronze source table, NOT from stg_colorado_business_entities.
--
-- Why bypass the staging view?
--   Snapshots run before dbt models in `dbt build` order. If we ref() a staging
--   *view*, Snowflake re-executes the full staging transformation during the snapshot
--   scan, which is redundant — the snapshot only needs the raw identifiers and the
--   mutable fields listed in check_cols above.
--
--   Reading from the bronze table also ensures the snapshot captures the pre-staging
--   state, giving us a true audit trail of the raw source, not dbt's interpretation
--   of it.  dim_business then transforms the snapshot output (post-staging-logic).
--
-- Columns selected:
--   - Precisely the fields needed to evaluate check_cols + reconstruct history.
--   - `principal_address_1` is included for historical audit completeness even
--     though it is not a check_col (address changes without city/zip changes are
--     rare and not subsidy-tier-defining).
--   - `_ingested_at` is excluded: it changes on every load and would trigger
--     false-positive snapshot updates if included.

select
    entityid                                    as entity_id,
    entityname                                  as entity_name,
    entitystatus                                as entity_status,
    entitytype                                  as entity_type,
    cast(entityformdate as date)                as entity_form_date,
    jurisdictonofformation                      as jurisdiction_of_formation,
    principaladdress1                           as principal_address_1,
    principalcity                               as principal_city,
    principalstate                              as principal_state,
    principalzipcode                            as principal_zip_code

from {{ source('bronze', 'colorado_business_entities') }}

-- Deduplicate within the source before snapshotting.
-- The bronze table is append-only (multiple rows per entity_id per day).
-- We keep only the most recently ingested record per entity to avoid
-- the snapshot treating the same-day duplicate as a new version.
qualify row_number() over (
    partition by entityid
    order by _ingested_at desc
) = 1

{% endsnapshot %}