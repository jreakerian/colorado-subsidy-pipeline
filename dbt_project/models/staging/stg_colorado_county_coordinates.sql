{{
  config(
    materialized='view',
    tags=['staging', 'bronze'],
    docs={'node_color': 'purple'}
  )
}}

with source as (
  select * from {{ source('bronze', 'colorado_county_coordinates') }}
),

cleaned as (
  select
    county,
    label,
    cent_lat,
    cent_long
  from source
)

select * from cleaned