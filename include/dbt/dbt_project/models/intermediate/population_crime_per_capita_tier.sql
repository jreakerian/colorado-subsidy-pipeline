{{
  config(
    materialized='table',
    tags=['intermediate', 'tier_ranking'],
    meta={
      'owner': 'data-engineering',
      'tier': 'intermediate',
      'description': 'Crime-per-capita tier per county (1-4). Higher crime per 1,000 residents = higher tier = more B.A.S.E. need. Feeds final_county_tier_rank.'
    }
  )
}}

with crimes as (
    select * from {{ ref('int_crimes_unified') }}
),

population as (
    -- int_income_population_unified merges population into the income model
    select
        county,
        year,
        total_population
    from {{ ref('int_income_population_unified') }}
    where
        total_population is not null
        and total_population > 0
),

yearly_crime_pop as (
    select
        c.county_name as county,
        c.incident_year as year,
        p.total_population,
        count(*) as total_crimes
    from crimes as c
    inner join population as p
        on
            lower(trim(c.county_name)) = replace(lower(trim(p.county)), ' county', '')
            and c.incident_year = p.year
    group by c.county_name, c.incident_year, p.total_population
),

avg_crime_per_capita as (
    select
        county,
        avg(cast(total_crimes as double) / nullif(total_population, 0) * 1000) as avg_crime_per_1000
    from yearly_crime_pop
    group by county
),

percentile_ranked as (
    select
        county,
        avg_crime_per_1000,
        percent_rank() over (order by avg_crime_per_1000) as crime_percentile
    from avg_crime_per_capita
)

select
    county,
    avg_crime_per_1000,
    crime_percentile,
    case
        when crime_percentile >= 0.75 then 4
        when crime_percentile >= 0.50 then 3
        when crime_percentile >= 0.25 then 2
        else 1
    end as crime_per_capita_tier
from percentile_ranked
