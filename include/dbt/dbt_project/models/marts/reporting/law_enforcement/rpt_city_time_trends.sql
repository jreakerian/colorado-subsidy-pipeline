{{
  config(
    materialized='table',
    tags=['marts', 'reporting', 'city', 'kpi'],
    meta={
      'owner': 'analytics',
      'kpis': ['city_kpi_1', 'city_kpi_6'],
      'description': 'City KPI 1 & 6. Seasonal crime trends and day-of-week crime patterns per city. One row per city × month × day_of_week.'
    }
  )
}}

/*
  City KPI 1: Seasonal crime trends for each city.
  City KPI 6: Crime trends by day of week per city.

  Uses city_geo_key (Phase 1.2) to resolve the city-level row in dim_geography.
  Only includes rows where city_geo_key is not null (i.e., city was successfully resolved).
*/

with crimes as (
    select
        city_geo_key,
        date_key,
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

dates as (
    select
        date_key,
        month,
        month_name,
        season,
        day_of_week,
        day_name
    from {{ ref('dim_date') }}
),

joined as (
    select
        g.city_name,
        g.county_name,
        d.month,
        d.month_name,
        d.season,
        d.day_of_week,
        d.day_name,
        count(*) as total_crimes
    from crimes as c
    inner join geo as g
        on c.city_geo_key = g.geo_key
    inner join dates as d
        on c.date_key = d.date_key
    group by
        g.city_name,
        g.county_name,
        d.month,
        d.month_name,
        d.season,
        d.day_of_week,
        d.day_name
),

final as (
    select
        city_name,
        county_name,
        month,
        month_name,
        season,
        day_of_week,
        day_name,
        total_crimes,
        -- Window: average crimes for this city in this month (across all years / day-of-weeks)
        round(
            avg(total_crimes) over (partition by city_name, month_name),
            1
        ) as avg_monthly_crimes,
        -- Window: average crimes for this city on this day-of-week (across all months)
        round(
            avg(total_crimes) over (partition by city_name, day_of_week),
            1
        ) as avg_dow_crimes
    from joined
)

select * from final
order by city_name, month, day_of_week
