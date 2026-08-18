{{
  config(
    materialized='table',
    tags=['marts', 'dimension'],
    meta={
      'owner': 'analytics',
      'tier': 'marts',
      'pii': true,
      'pii_columns': ['entity_name', 'principal_address'],
      'description': 'Business entity dimension. Active Colorado businesses in good standing eligible for B.A.S.E. subsidy evaluation. Applies status filter and zip validation here'
    }
  )
}}

with staged as (
  select * from {{ ref('stg_colorado_business_entities') }}
),

city_county_zip as (
  select * from {{ ref('colorado_city_county_zip') }}
),

-- B.A.S.E. program eligibility filter: only active businesses in good standing
-- qualify for subsidy evaluation. 
eligible as (
  select
    entity_id,
    entity_name,
    principal_address_1                         as principal_address,
    principal_city,
    principal_state,
    principal_zip_code,
    -- Zip validation: B.A.S.E. program requires a valid 5-digit zip to perform
    -- county lookups.
    case
      when regexp_like(principal_zip_code, '^\\d{5}(-\\d{4})?$')
        then substring(principal_zip_code, 1, 5)
      else null
    end                                         as clean_zip_code,
    entity_status,
    entity_type,
    entity_form_date,
    jurisdiction_of_formation
  from staged
  where entity_status = 'Good Standing'    -- B.A.S.E. eligibility: active status required
),

-- Resolve county from ZIP lookup for businesses where city alone is ambiguous
mapped as (
  select
    e.entity_id,
    e.entity_name,
    e.principal_address,
    e.principal_city,
    coalesce(
      lower(trim(e.principal_city)),
      ccz.city
    )                                           as resolved_city,
    coalesce(
      lower(trim(ccz.county)),
      lower(trim(e.principal_state))
    )                                           as resolved_county,
    e.principal_state,
    e.clean_zip_code,
    e.entity_status,
    e.entity_type,
    e.entity_form_date,
    e.jurisdiction_of_formation
  from eligible e
  left join city_county_zip ccz
    on e.clean_zip_code = cast(ccz.zip_code as varchar)
),

final as (
  select
    row_number() over (order by entity_id)  as business_key,
    entity_id,
    entity_name,
    principal_address,
    principal_city,
    resolved_city,
    resolved_county                         as principal_county,
    principal_state,
    clean_zip_code                          as principal_zip,
    entity_status,
    entity_type,
    entity_form_date                        as formation_date,
    jurisdiction_of_formation               as jurisdiction,
    true                                    as is_active  -- all rows here passed entity_status = 'Good Standing'
  from mapped
  where resolved_county is not null
)

select * from final
