{{
  config(
    materialized='table',
    tags=['marts', 'reporting', 'county', 'kpi'],
    meta={'kpi': 'police_agency_baseline_crime_count', 'owner': 'analytics'}
  )
}}

-- KPI: Set a 5% crime reduction goal per police agency per county.
-- Thin wrapper over fct_crimes + dim_agency.
with crimes as (
  select * from {{ ref('fct_crimes') }}
),

agency as (
  select * from {{ ref('dim_agency') }}
)

select
  a.primary_county                        as county_name,
  a.agency_name,
  count(*)                                as total_crimes,
  round(count(*) * 0.95)                  as target_crimes_5pct_reduction,
  min(c.incident_date)                    as first_incident_date,
  max(c.incident_date)                    as last_incident_date
from crimes c
join agency a using (agency_key)
group by a.primary_county, a.agency_name
