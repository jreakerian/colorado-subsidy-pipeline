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
    primary_county as county_name,
    incident_date,
    incident_hour,
    offense_name,
    crime_against,
    offense_category_name,
    age_num,
    '1997_2015' as source_period
  from source
)

select * from cleaned