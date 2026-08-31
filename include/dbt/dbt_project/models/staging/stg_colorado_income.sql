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
        cast(statename as string) as state_name,
        cast(areaname as string) as county,
        cast(periodyear as integer) as year,
        cast(inctype as integer) as income_type_code,    -- raw integer: 1=Per Capita, 2=Median HH, 3=Total Personal
        cast(incdesc as string) as income_description,  -- raw label from source; do not rely on for pivoting
        cast(try_to_number(replace(income, ',', '')) as integer) as income,
        cast(try_to_number(replace(population, ',', '')) as integer) as population
    from source
    where
        statename = 'Colorado'
        and areatype = 4  -- county-level records only (structural filter, not business logic)
)

select * from cleaned
