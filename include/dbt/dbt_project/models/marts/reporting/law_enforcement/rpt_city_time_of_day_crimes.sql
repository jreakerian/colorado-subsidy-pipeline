{{
  config(
    materialized='table',
    tags=['marts', 'reporting', 'city', 'kpi'],
    meta={
      'owner': 'analytics',
      'kpis': ['city_kpi_2', 'city_kpi_4'],
      'description': 'City KPI 2 & 4. Top 3 daytime crimes and top 3 nighttime crimes per city. One row per city × time_of_day × offense_category_name (rank ≤ 3).'
    }
  )
}}

/*
  City KPI 2: Top 3 daytime crimes per city (6 AM – 6 PM).
  City KPI 4: Top 3 nighttime crimes per city (6 PM – 6 AM).

  Uses city_geo_key (Phase 1.2) to resolve the city-level row in dim_geography.
  Row rank is per city × time_of_day; rank 1 = most common crime in that slot.
*/

with crimes as (
    select
        city_geo_key,
        offense_key,
        time_of_day,
        1 as crime_count
    from {{ ref('fct_crimes') }}
    where city_geo_key is not null
),

geo as (
    select
        geo_key,
        city_name,
        county_name
    from {{ ref('dim_geography') }}
    where city_name != '[County Level]'
),

offenses as (
    select
        offense_key,
        offense_category_name,
        crime_against
    from {{ ref('dim_offense') }}
),

aggregated as (
    select
        g.city_name,
        g.county_name,
        c.time_of_day,
        o.offense_category_name,
        o.crime_against,
        count(*) as crime_count
    from crimes as c
    inner join geo as g
        on c.city_geo_key = g.geo_key
    inner join offenses as o
        on c.offense_key = o.offense_key
    group by
        g.city_name,
        g.county_name,
        c.time_of_day,
        o.offense_category_name,
        o.crime_against
),

ranked as (
    select
        city_name,
        county_name,
        time_of_day,
        offense_category_name,
        crime_against,
        crime_count,
        row_number() over (
            partition by city_name, time_of_day
            order by crime_count desc
        ) as rnk
    from aggregated
)

select
    city_name,
    county_name,
    time_of_day,
    offense_category_name,
    crime_against,
    crime_count,
    rnk
from ranked
where rnk <= 3
order by city_name, time_of_day, rnk
