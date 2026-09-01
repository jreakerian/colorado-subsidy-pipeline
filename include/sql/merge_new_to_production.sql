-- merge_new_to_production.sql
--
-- Purpose : Write-once deduplication gate between the bronze raw table
--           and the production source table that dbt reads from.
--
-- Placeholders replaced by the Airflow task at runtime:
--   {raw_table}   → e.g. RAW_DEV.colorado_business_entities_raw
--   {prod_table}  → e.g. RAW_DEV.colorado_business_entities
--   {yesterday}   → YYYY-MM-DD injected via {{ ds }} macro

MERGE INTO {prod_table} AS target
USING (
    SELECT DISTINCT
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
        _ingested_at
    FROM {raw_table}
    WHERE _source_date = '{yesterday}'
      AND entityid IS NOT NULL          -- guard: skip rows with no natural key
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
        entityformdate,
        _ingested_at
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
        source.entityformdate,
        source._ingested_at
    )
WHEN MATCHED THEN
    UPDATE SET
        target.entityname = source.entityname,
        target.principaladdress1 = source.principaladdress1,
        target.principaladdress2 = source.principaladdress2,
        target.principalcity = source.principalcity,
        target.principalstate = source.principalstate,
        target.principalzipcode = source.principalzipcode,
        target.principalcountry = source.principalcountry,
        target.entitystatus = source.entitystatus,
        target.jurisdictonofformation = source.jurisdictonofformation,
        target.entitytype = source.entitytype,
        target.entityformdate = source.entityformdate,
        target._ingested_at = source._ingested_at