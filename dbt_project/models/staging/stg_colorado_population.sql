{{
  config(
    materialized='view',
    tags=['staging', 'bronze'],
    docs={'node_color': 'purple'}
  )
}}

with source as (
  select * from {{ source('bronze', 'colorado_population') }}
),

cleaned as (
  select
    county,
    year,
    age,
    malepopulation,
    femalepopulation,
    totalpopulation,
    datatype,
    fipscode
  from source
  where county is not null
    and year between {{ var('start_date')[:4] | int }} and {{ var('end_date')[:4] | int }}
)

select * from cleaned