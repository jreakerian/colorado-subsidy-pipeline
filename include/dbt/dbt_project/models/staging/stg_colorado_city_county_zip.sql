{{
  config(
    materialized='view',
    tags=['staging', 'bronze'],
    docs={'node_color': 'purple'}
  )
}}

-- ── stg_colorado_city_county_zip ────────────────────────────────────────────────
-- Thin staging layer over the colorado_city_county_zip seed.
--
-- Why this exists:
--   Seeds are raw data. Marts (dim_geography, dim_business) must not reference
--   seeds directly — all raw data must flow through a staging model first so
--   that column renames, type casts, and normalisations live in one place.
--
-- Transformations applied here:
--   - zip_code cast to VARCHAR(10) to ensure consistent join behaviour
--     (seeds may infer INTEGER, which would break string-join predicates).
--   - city and county lowercased and trimmed to normalise for downstream joins.

with source as (
    select * from {{ ref('colorado_city_county_zip') }}
),

cleaned as (
    select
        cast(zip_code as varchar(10))   as zip_code,
        lower(trim(city))               as city,
        lower(trim(county))             as county
    from source
)

select * from cleaned
