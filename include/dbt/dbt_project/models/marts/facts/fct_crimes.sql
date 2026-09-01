{{
  config(
    materialized='table',
    tags=['marts', 'fact'],
    meta={
      'owner': 'analytics',
      'tier': 'marts',
      'description': 'Core crime incident fact table. Granularity: 1 row per crime incident (1997-2020). All 16 KPIs aggregate from this table.'
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

        -- Geography: join on county (city_name = '[County Level]' for county-only records)
        g.geo_key
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

    -- Join to county-level geography (county-only grain, city = '[County Level]')
    left join dim_geo as g
        on
            lower(trim(split_part(c.county_name, ',', 1))) = lower(trim(g.county_name))
            and g.city_name = '[County Level]'
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
    geo_key,
    offense_key,
    agency_key,

    -- Measure (count is implicit; keep 1 row per incident)
    1 as crime_count
from joined
