

-- ── stg_colorado_county_boundaries ──────────────────────────────────────────────
-- Thin staging layer over the colorado_county_boundaries seed.
--
-- Why this exists:
--   Seeds are raw data. Marts must not reference seeds directly — all raw data
--   flows through staging first. This ensures any column rename or type change
--   in the seed is fixed in a single place.
--
-- Transformations applied here:
--   - label retained as-is (title-case county name, e.g. "Larimer") — dim_geography
--     handles the lower() normalisation at join time since it joins against both
--     title-case and lower-case consumers.
--   - cent_lat / cent_long cast to FLOAT to guard against seed type inference
--     inferring FIXED (NUMERIC) with excess precision.
--   - county uppercased to match how crime source data references county codes.

with source as (
    select * from COLORADO_CRIME_DB_PROD.PUBLIC.colorado_county_boundaries
),

cleaned as (
    select
        upper(trim(county))         as county_code,
        trim(label)                 as county_label,
        cast(cent_lat as float)     as cent_lat,
        cast(cent_long as float)    as cent_long
    from source
)

select * from cleaned