{{
  config(
    materialized='table',
    tags=['marts', 'dimension'],
    meta={
      'owner': 'analytics',
      'tier': 'marts',
      'description': 'Offense dimension. One row per unique offense category + crime_against classification. Centralizes all crime type filtering.'
    }
  )
}}

with source as (
    select * from {{ ref('int_crimes_unified') }}
),

distinct_offenses as (
    select distinct
        offense_category_name,
        offense_name,
        crime_against,
        offense_group   -- null for 1997-2015 records
    from source
    where
        offense_category_name is not null
        and crime_against in ('Property', 'Person', 'Society')
),

final as (
    select
        offense_category_name,
        offense_name,
        crime_against,
        row_number() over (order by crime_against, offense_category_name, offense_name) as offense_key,
        coalesce(offense_group, 'Unknown') as offense_group
    from distinct_offenses
)

select * from final
