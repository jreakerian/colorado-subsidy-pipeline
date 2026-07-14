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
    entityid                                        as entity_id,
    entityname                                      as entity_name,
    principaladdress1                               as principal_address_1,
    principaladdress2                               as principal_address_2,
    principalcity                                   as principal_city,
    principalstate                                  as principal_state,
    principalzipcode                                as principal_zip_code,
    principalcountry                                as principal_country,
    entitystatus                                    as entity_status,
    jurisdictonofformation                          as jurisdiction_of_formation,
    entitytype                                      as entity_type,
    cast(entityformdate as date)                    as entity_form_date,
    case 
      when REGEXP_LIKE(principalzipcode, '^\\d{5}(-\\d{4})?$') then SUBSTRING(principalzipcode, 1, 5)
      else null
    end                                             as clean_zip_code
  from source
  where principalstate = 'CO'
    and entitystatus = 'Good Standing'
)

select * from cleaned