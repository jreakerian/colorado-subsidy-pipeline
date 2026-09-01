{{
  config(
    materialized='table',
    tags=['marts', 'fact'],
    meta={
      'owner': 'analytics',
      'tier': 'marts',
      'description': 'Annual county-level income and population snapshot fact. Granularity: 1 row per county per year (1997-2020). YoY growth is computed once in int_income_population_unified.'
    }
  )
}}

with unified as (
    select * from {{ ref('int_income_population_unified') }}
),

dim_geo as (
    select
        geo_key,
        county_name
    from {{ ref('dim_geography') }}
    where city_name = '[County Level]'
)

select
    g.geo_key,
    u.year,
    -- Synthetic Jan-1-of-year date so this fact has a genuine time dimension
    -- for the semantic layer (MetricFlow needs a real DATE/TIMESTAMP column
    -- to support time-grain rollups and cross-model time-aligned joins;
    -- `year` alone is just an integer).
    cast(u.year || '-01-01' as date) as year_date,
    u.median_household_income,
    u.per_capita_income,
    u.total_personal_income,
    u.total_population,
    u.male_population,
    u.female_population,
    u.population_yoy_change,
    u.population_growth_pct
from unified as u
left join dim_geo as g
    on replace(lower(trim(u.county)), ' county', '') = lower(trim(g.county_name))
