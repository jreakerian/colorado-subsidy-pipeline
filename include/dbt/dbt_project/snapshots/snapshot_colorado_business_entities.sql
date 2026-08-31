{% snapshot snapshot_colorado_business_entities %}

{{
    config(
        target_schema  = 'silver',
        target_database = env_var('DBT_DATABASE', 'COLORADO_CRIME_DB_DEV'),
        unique_key     = 'entity_id',
        strategy       = 'check',
        check_cols     = [
            'entity_status',
            'principal_zip_code',
            'principal_city',
            'entity_name',
            'entity_type',
        ],
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



-- NOTE: No ORDER BY here.
-- dbt_valid_to (the basis for is_current) is a dbt-managed column appended
-- AFTER this source query runs — it does not exist here and cannot be sorted on.
-- Additionally, the snapshot is append-only: new changed rows are inserted on
-- every incremental run regardless of any ORDER BY, so sort order drifts.
-- Physical ordering by is_current DESC, entity_status is handled in dim_business,
-- which does a full table rebuild on every run and has access to all derived columns.

{% endsnapshot %}