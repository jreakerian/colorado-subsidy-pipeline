{{
  config(
    materialized='table',
    tags=['marts', 'dimension'],
    meta={
      'owner': 'analytics',
      'tier': 'marts',
      'description': 'Police agency dimension. Normalized agency names with primary county. Supports the 5% crime reduction KPI baseline per agency.'
    }
  )
}}

with crimes as (
  select * from {{ ref('int_crimes_unified') }}
),

distinct_agencies as (
  select distinct
    agency_name,
    county_name
  from crimes
  where agency_name is not null
    and county_name is not null
),

-- If an agency appears with multiple counties (multi-jurisdiction),
-- take their most frequently recorded county as the primary
agency_ranked as (
  select
    agency_name,
    county_name,
    count(*) as record_count,
    row_number() over (partition by agency_name order by count(*) desc) as rn
  from crimes
  group by agency_name, county_name
),

final as (
  select
    row_number() over (order by agency_name) as agency_key,
    agency_name,
    county_name as primary_county
  from agency_ranked
  where rn = 1
    and agency_name is not null
)

select * from final
