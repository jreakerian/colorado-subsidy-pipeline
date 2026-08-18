{{
  config(
    materialized='table',
    tags=['marts', 'reporting', 'business', 'kpi', 'base_program'],
    meta={
      'kpi': 'business_subsidy_tier_lookup',
      'owner': 'analytics',
      'description': 'Public-facing B.A.S.E. program tier lookup. Businesses search by entity_id or name to see their assigned subsidy tier. OEDIT uses this to automatically notify eligible businesses.'
    }
  )
}}

-- The front-facing business tier search tool for the B.A.S.E. program.
-- Businesses search by entity_id or entity_name to retrieve their assigned tier.
with tiers as (
  select * from {{ ref('fct_business_subsidy_tiers') }}
)

select
  entity_id,
  entity_name,
  principal_city,
  principal_county,
  principal_zip,
  entity_type,
  formation_date,
  crime_tier,
  income_tier,
  population_tier,
  composite_tier,
  subsidy_tier_label,
  qualifies_for_subsidy,
  notification_eligible,
  case composite_tier
    when 4 then 'Your business qualifies for Maximum Security Subsidy under the B.A.S.E. program.'
    when 3 then 'Your business qualifies for Enhanced Security Subsidy under the B.A.S.E. program.'
    when 2 then 'Your business qualifies for Standard review under the B.A.S.E. program.'
    when 1 then 'Your business is eligible for Basic Review under the B.A.S.E. program.'
    else        'Tier not yet assigned. Please contact OEDIT.'
  end                                     as subsidy_message
from tiers
