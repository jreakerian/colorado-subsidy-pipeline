{{
  config(
    materialized='table',
    tags=['marts', 'fact'],
    meta={
      'owner': 'analytics',
      'tier': 'marts',
      'description': 'Core crime incident fact table. Granularity: 1 row per crime incident (1997-2024). All 16 KPIs aggregate from this table. geo_key = county grain; city_geo_key = city grain (nullable).'
    }
  )
}}

/*
  This is the central fact table of the star schema.
  Every KPI mart is a GROUP BY on this table joined to the relevant dimensions.
  Surrogate keys (date_key, geo_key, offense_key, agency_key) link to dim_ tables.
*/

with crimes as (
    select * from {{ ref('int_crimes_unified') }}
),

dim_date as (
    select
        date_key,
        full_date,
        date_day
    from {{ ref('dim_date') }}
),

dim_geo as (
    select
        geo_key,
        city_name,
        county_name,
        zip_code
    from {{ ref('dim_geography') }}
),

dim_offense as (
    select
        offense_key,
        offense_category_name,
        offense_name,
        crime_against,
        offense_group
    from {{ ref('dim_offense') }}
),

dim_agency as (
    select
        agency_key,
        agency_name,
        primary_county
    from {{ ref('dim_agency') }}
),

-- Join dimensions to resolve surrogate keys
joined as (
    select
        c.incident_date,
        c.county_name,
        c.agency_name,
        c.offense_category_name,
        c.offense_name,
        c.crime_against,
        c.incident_hour,
        c.time_of_day,
        c.age_num,
        c.source_period,

        -- Dimension surrogate keys
        d.date_key,
        ag.agency_key,
        o.offense_key,

        -- Geography keys
        g.geo_key,
        city_g.geo_key as city_geo_key
    from crimes as c

    left join dim_date as d
        on c.incident_date = d.date_day

    left join dim_agency as ag
        on c.agency_name = ag.agency_name

    left join dim_offense as o
        on
            c.offense_category_name = o.offense_category_name
            and c.offense_name = o.offense_name
            and c.crime_against = o.crime_against

    -- County-level geography join (preserved for backward compatibility)
    -- geo_key resolves to the county-level row in dim_geography
    left join dim_geo as g
        on
            lower(trim(split_part(c.county_name, ',', 1))) = lower(trim(g.county_name))
            and g.city_name = '[County Level]'

    -- City-level geography join (Phase 1.2)
    -- city_geo_key resolves to the city-level row when city_name is known
    -- and is a real city (not '[County Level]', not NULL).
    left join dim_geo as city_g
        on
            lower(trim(split_part(c.county_name, ',', 1))) = lower(trim(city_g.county_name))
            and lower(trim(c.city_name)) = lower(trim(city_g.city_name))
            and city_g.city_name != '[County Level]'
            and c.city_name is not null
)

select
    -- Degenerate dimensions (low-cardinality values kept on the fact)
    incident_date,
    incident_hour,
    time_of_day,
    age_num,
    source_period,

    -- Foreign keys to dimensions
    date_key,
    geo_key,          -- county-level geography key (always populated)
    city_geo_key,     -- city-level geography key (NULL if city unknown)
    offense_key,
    agency_key,

    -- Measure (count is implicit; keep 1 row per incident)
    1 as crime_count
from joined
