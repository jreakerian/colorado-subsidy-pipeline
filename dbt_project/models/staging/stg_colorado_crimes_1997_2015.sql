{{
  config(
    materialized='view',
    tags=['staging', 'bronze'],
    docs={'node_color': 'purple'}
  )
}}

with source as (
  select * from {{ source('bronze', 'colorado_crimes_1997_2015') }}
),

cleaned as (
  select
    agency_name,
    agency_type_name,
    city_name,
    primary_county                        as county_name,
    cast(incident_date as date)           as incident_date,
    cast(incident_hour as integer)        as incident_hour,
    offense_name,
    crime_against,
    offense_category_name,
    cast(age_num as integer)              as age_num,
    '1997_2015'                           as source_period
  from source
)

select * from cleaned