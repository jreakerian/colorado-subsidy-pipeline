{{
  config(
    materialized='table',
    tags=['intermediate', 'tier_ranking'],
    meta={
      'owner': 'data-engineering',
      'tier': 'intermediate',
      'description': 'Median household income tier per county (inverse: lower income = higher tier = more B.A.S.E. need). Feeds final_county_tier_rank.'
    }
  )
}}

with income as (
  select * from {{ ref('int_income_population_unified') }}
),

avg_income as (
  select
    county,
    avg(median_household_income) as avg_median_household_income
  from income
  where median_household_income is not null
  group by county
),

percentile_ranked as (
  select
    county,
    avg_median_household_income,
    percent_rank() over (order by avg_median_household_income) as income_percentile
  from avg_income
)

select
  county,
  avg_median_household_income,
  income_percentile,
  case
    when income_percentile >= 0.75 then 1
    when income_percentile >= 0.50 then 2
    when income_percentile >= 0.25 then 3
    else 4
  end as income_tier
from percentile_ranked