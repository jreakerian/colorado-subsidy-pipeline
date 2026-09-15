

/*
  City KPI 3: Average age of individuals per crime type in each city.
  City KPI 5: Crime distribution by type (Property / Person / Society) per city.

  Uses city_geo_key (Phase 1.2) to resolve the city-level row in dim_geography.
  avg_offender_age is NULL for records where age_num was not recorded (~47% of
  the unified dataset).
*/

with crimes as (
    select
        city_geo_key,
        offense_key,
        age_num
    from COLORADO_CRIME_DB_PROD.gold.fct_crimes
    where city_geo_key is not null
),

geo as (
    select
        geo_key,
        city_name,
        county_name
    from COLORADO_CRIME_DB_PROD.gold.dim_geography
    where city_name != '[County Level]'
),

offenses as (
    select
        offense_key,
        offense_category_name,
        crime_against
    from COLORADO_CRIME_DB_PROD.gold.dim_offense
),

aggregated as (
    select
        g.city_name,
        g.county_name,
        o.offense_category_name,
        o.crime_against,
        count(*)                        as total_crimes,
        round(avg(c.age_num), 1)        as avg_offender_age,
        -- Total crimes per city — used to compute the share below
        sum(count(*)) over (
            partition by g.city_name
        )                               as city_total_crimes
    from crimes as c
    inner join geo as g
        on c.city_geo_key = g.geo_key
    inner join offenses as o
        on c.offense_key = o.offense_key
    group by
        g.city_name,
        g.county_name,
        o.offense_category_name,
        o.crime_against
)

select
    city_name,
    county_name,
    offense_category_name,
    crime_against,
    total_crimes,
    avg_offender_age,
    round(
        total_crimes * 100.0 / nullif(city_total_crimes, 0),
        2
    ) as pct_of_city_crimes
from aggregated
order by city_name, total_crimes desc