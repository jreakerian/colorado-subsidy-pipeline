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
  select geo_key, county_name
  from {{ ref('dim_geography') }}
  where city_name = '[County Level]'
)

select
  g.geo_key,
  u.year,
  u.median_household_income,
  u.per_capita_income,
  u.total_personal_income,
  u.total_population,
  u.male_population,
  u.female_population,
  u.population_yoy_change,
  u.population_growth_pct
from unified u
left join dim_geo g
  on lower(trim(u.county)) = lower(trim(g.county_name))
