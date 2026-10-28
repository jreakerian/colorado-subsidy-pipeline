-- merge_new_to_production.sql
--
-- Purpose : Idempotent deduplication gate between the bronze raw table
--           and the production source table that dbt reads from.
--
-- Executed by SQLExecuteQueryOperator (airflow.providers.common.sql).
-- Table names are injected via Jinja params (safe for identifiers):
--   {{ params.raw_table }}   → e.g. RAW.colorado_business_entities_raw
--   {{ params.prod_table }}  → e.g. RAW.colorado_business_entities
-- The partition date is passed as a DB-API bind parameter (prevents SQL injection):
--   %(target_date)s          → YYYY-MM-DD value from the run's data interval
--
-- Deduplication strategy:
--   QUALIFY ROW_NUMBER() OVER (PARTITION BY entityid ORDER BY _ingested_at DESC) = 1
--   picks the most-recently ingested record when the same entityid appears more
--   than once in a partition (e.g. duplicate API responses on a retry).
--   This is strictly superior to SELECT DISTINCT which cannot resolve conflicts
--   when two rows differ only in a non-key field.

MERGE INTO {{ params.prod_table }} AS target
USING (
    SELECT
        entityid,
        entityname,
        principaladdress1,
        principaladdress2,
        principalcity,
        principalstate,
        principalzipcode,
        principalcountry,
        entitystatus,
        jurisdictonofformation,
        entitytype,
        entityformdate,
        _source_date
    FROM {{ params.raw_table }}
    WHERE _source_date = %(target_date)s
      AND entityid IS NOT NULL          -- guard: skip rows with no natural key
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY entityid
        ORDER BY _ingested_at DESC      -- latest ingestion wins on duplicates
    ) = 1
) AS source
ON target.entityid = source.entityid   -- raw string comparison; dbt casts downstream
WHEN NOT MATCHED THEN
    INSERT (
        entityid,
        entityname,
        principaladdress1,
        principaladdress2,
        principalcity,
        principalstate,
        principalzipcode,
        principalcountry,
        entitystatus,
        jurisdictonofformation,
        entitytype,
        entityformdate
    )
    VALUES (
        source.entityid,
        source.entityname,
        source.principaladdress1,
        source.principaladdress2,
        source.principalcity,
        source.principalstate,
        source.principalzipcode,
        source.principalcountry,
        source.entitystatus,
        source.jurisdictonofformation,
        source.entitytype,
        source.entityformdate
    )
WHEN MATCHED THEN
    UPDATE SET
        target.entityname             = source.entityname,
        target.principaladdress1      = source.principaladdress1,
        target.principaladdress2      = source.principaladdress2,
        target.principalcity          = source.principalcity,
        target.principalstate         = source.principalstate,
        target.principalzipcode       = source.principalzipcode,
        target.principalcountry       = source.principalcountry,
        target.entitystatus           = source.entitystatus,
        target.jurisdictonofformation = source.jurisdictonofformation,
        target.entitytype             = source.entitytype,
        target.entityformdate         = source.entityformdate;
