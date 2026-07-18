{{
  config(
    materialized='view',
    tags=['staging', 'bronze'],
    docs={'node_color': 'purple'}
  )
}}

with source as (
  select * from {{ source('bronze', 'colorado_crimes_2016_2020') }}
),

cleaned as (
  select
    pub_agency_name                       as agency_name,
    county_name,
    cast(try_to_date(incident_date, 'MM/DD/YYYY') as date) as incident_date,
    cast(incident_hour as integer)        as incident_hour,
    offense_name,
    crime_against,
    offense_category_name,
    offense_group,
    cast(age_num as integer)              as age_num,
    '2016_2020'                           as source_period
  from source
)

select * from cleaned