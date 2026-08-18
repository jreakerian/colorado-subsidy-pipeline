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
    cast(county as string) as county,
    cast(year as integer) as year,
    cast(age as integer) as age,
    cast(try_to_number(replace(malepopulation, ',', '')) as integer)   as male_population,
    cast(try_to_number(replace(femalepopulation, ',', '')) as integer) as female_population,
    cast(try_to_number(replace(totalpopulation, ',', '')) as integer)  as total_population,
    cast(datatype as string)         as data_type,
    cast(fipscode as integer)         as fips_code
  from source
  where county is not null   -- structural: exclude rows with no geographic identifier
)

select * from cleaned
where total_population > 0  -- exclude historical placeholder rows (e.g. Broomfield pre-2001,
                             -- which was not a county until Nov 2001 and has zero-value entries
                             -- for 1990-1999 in the source dataset)