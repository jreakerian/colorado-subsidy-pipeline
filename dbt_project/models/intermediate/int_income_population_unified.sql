{{
  config(
    materialized='table',
    tags=['intermediate', 'core'],
    meta={
      'owner': 'data-engineering',
      'tier': 'intermediate',
      'pii': false,
      'description': 'Unified county-year income and population snapshot. Single source for all income/population KPIs. Applies year-range scoping and income_type_code '
    }
  )
}}

with income as (
  select * from {{ ref('stg_colorado_income') }}
),

population as (
  -- Year-range filter
  select * from {{ ref('stg_colorado_population') }}
  where year between {{ var('start_date')[:4] | int }} and {{ var('end_date')[:4] | int }}
),

income_typed as (
  select
    county,
    year,
    income,
    population                                  as reported_population,
    case 
      when income_type_code = 1 then 'Per Capita Personal Income'
      when income_type_code = 2 then 'Median Household Income'
      when income_type_code = 3 then 'Total Personal Income'
      else 'Unknown'
    end                                         as income_type
  from income
  where year between {{ var('start_date')[:4] | int }} and {{ var('end_date')[:4] | int }}
    and income is not null
),

-- Pivot income types to columns: one row per county + year
income_pivoted as (
  select
    county,
    year,
    max(reported_population)                                            as reported_population,
    max(case when income_type = 'Median Household Income'    then income end) as median_household_income,
    max(case when income_type = 'Per Capita Personal Income' then income end) as per_capita_income,
    max(case when income_type = 'Total Personal Income'      then income end) as total_personal_income
  from income_typed
  group by county, year
),

-- Aggregate population to county + year (stg passes all age/gender rows per year)
population_agg as (
  select
    county,
    year,
    sum(total_population) as total_population,
    sum(male_population)  as male_population,
    sum(female_population) as female_population
  from population
  group by county, year
)

select
  i.county,
  i.year,
  i.median_household_income,
  i.per_capita_income,
  i.total_personal_income,
  coalesce(p.total_population, i.reported_population) as total_population,
  p.male_population,
  p.female_population
from income_pivoted i
left join population_agg p
  on lower(trim(i.county)) = lower(trim(p.county))
  and i.year = p.year
where i.county not in ('Colorado', 'United States')  -- exclude state/national rollups
