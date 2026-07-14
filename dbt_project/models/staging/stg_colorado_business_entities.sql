{{
  config(
    materialized='view',
    tags=['staging', 'bronze'],
    docs={'node_color': 'purple'}
  )
}}

with source as (
  select * from {{ source('bronze', 'colorado_business_entities') }}
),

cleaned as (
  select
    entityid,
    entityname,
    principaladdress1,
    principaladdress2,
    principalcity,
    principalstate,
    principalzipcode,
    principalcountry,
    entitystatus,
    jurisdictonofformation,
    entitytype,
    cast(entityformdate as date) as entityformdate,
    case 
      when REGEXP_LIKE(principalzipcode, '^\\d{5}(-\\d{4})?$') then SUBSTRING(principalzipcode, 1, 5)
      else null
    end as clean_zipcode
  from source
  where principalstate = 'CO'
    and entitystatus = 'Good Standing'
)

select * from cleaned