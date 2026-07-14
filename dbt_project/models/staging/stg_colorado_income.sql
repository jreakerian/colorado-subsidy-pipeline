{{
  config(
    materialized='view',
    tags=['staging', 'bronze'],
    docs={'node_color': 'purple'}
  )
}}

with source as (
  select * from {{ source('bronze', 'colorado_income') }}
),

cleaned as (
  select
    statename   as state_name,
    areaname    as county,
    periodyear  as year,
    inctype     as income_type_code,
    incdesc     as income_description,
    income,
    population,
    case 
      when inctype = 1 then 'Per Capita Personal Income'
      when inctype = 2 then 'Median Household Income'
      when inctype = 3 then 'Total Personal Income'
      else 'Unknown'
    end as income_type
  from source
  where statename = 'Colorado'
    and areatype = 4  -- County level
)

select * from cleaned