

with income as (
    select
        *,
        
  lower(
    trim(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            lower(trim(county)),
            ',\\s*(co|colorado)\\s*$', ''   -- strip ", CO" or ", Colorado" suffix
          ),
          '\\s+county\\s*$', ''             -- strip trailing " county"
        ),
        '\\s+', ' '                         -- collapse internal whitespace
      )
    )
  )
 as county_normalized
    from COLORADO_CRIME_DB_DEV.raw.stg_colorado_income
    where
        year between 1997 and 2024
        and income is not null
        and county not in ('Colorado', 'United States') -- exclude state/national rollups
),

population as (
    -- Year-range filter
    select
        *,
        
  lower(
    trim(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            lower(trim(county)),
            ',\\s*(co|colorado)\\s*$', ''   -- strip ", CO" or ", Colorado" suffix
          ),
          '\\s+county\\s*$', ''             -- strip trailing " county"
        ),
        '\\s+', ' '                         -- collapse internal whitespace
      )
    )
  )
 as county_normalized
    from COLORADO_CRIME_DB_DEV.raw.stg_colorado_population
    where year between 1997 and 2024
),


-- Pivot income types to columns: one row per county + year
income_pivoted as (
    select
        county,
        county_normalized,
        year,
        max(population) as reported_population,
        max(case when income_type_code = 2 then income end) as median_household_income,
        max(case when income_type_code = 1 then income end) as per_capita_income,
        max(case when income_type_code = 3 then income end) as total_personal_income
    from income
    group by county, county_normalized, year
),

-- Aggregate population to county + year (stg passes all age/gender rows per year)
population_agg as (
    select
        county,
        county_normalized,
        year,
        sum(total_population) as total_population,
        sum(male_population) as male_population,
        sum(female_population) as female_population
    from population
    group by county, county_normalized, year
),


population_with_lag as (
    select
        county,
        county_normalized,
        year,
        total_population,
        male_population,
        female_population,
        lag(total_population) over (
            partition by county_normalized   -- partition on normalized key for consistency
            order by year
        ) as prior_year_population
    from population_agg
),

-- YoY population change: computed here once so the fact table is a thin wrapper.
-- LAG() over (county, year) gives the prior year's total population.
-- NULLIF guards against division by zero on the first year per county.
population_yoy as (
    select
        county,
        county_normalized,
        year,
        total_population,
        male_population,
        female_population,
        prior_year_population,

        -- Pure arithmetic from here — no window function re-evaluation
        total_population - prior_year_population as population_yoy_change,

        round(
            (total_population - prior_year_population)
            / nullif(prior_year_population, 0)
            * 100,
            4
        ) as population_growth_pct
    from population_with_lag
)

select
    i.county,
    i.county_normalized,
    i.year,
    i.median_household_income,
    i.per_capita_income,
    i.total_personal_income,
    p.male_population,
    p.female_population,
    p.prior_year_population,
    p.population_yoy_change,
    -- NULL on the first year per county (no prior year to compare against)
    p.population_growth_pct,
    coalesce(p.total_population, i.reported_population) as total_population
from income_pivoted as i
left join population_yoy as p
    on
        i.county_normalized = p.county_normalized
        and i.year = p.year