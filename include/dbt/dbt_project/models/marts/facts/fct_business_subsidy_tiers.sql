{{
  config(
    materialized='table',
    tags=['marts', 'fact', 'base_program'],
    meta={
      'owner': 'analytics',
      'tier': 'marts',
      'description': 'B.A.S.E. program core output. One row per eligible business with its composite subsidy tier. Combines crime tier, income tier, and population/crime-per-capita tier to determine security subsidy eligibility.'
    }
  )
}}

/*
  B.A.S.E. (Business Assistance for Security Enhancements) tier assignment.
  Tier logic: counties ranked 1-4 across three dimensions:
    - crime_tier:      1=lowest crime, 4=highest crime  (higher = more need)
    - income_tier:     1=highest income, 4=lowest income (higher = more need)
    - population_tier: 1=lowest crime-per-capita, 4=highest (higher = more need)
  composite_tier: weighted average rounded to nearest integer
  Businesses in Tier 3+ qualify for subsidy; Tier 4 = maximum subsidy.
*/

with businesses as (
    select * from {{ ref('dim_business') }}
),

county_tiers as (
    select * from {{ ref('final_county_tier_rank') }}
),

dim_geo as (
    select
        geo_key,
        county_name
    from {{ ref('dim_geography') }}
    where city_name = '[County Level]'
),

joined as (
    select
        b.business_key,
        b.entity_id,
        b.entity_name,
        b.principal_city,
        b.principal_county,
        b.principal_zip,
        b.entity_type,
        b.formation_date,
        b.is_active,
        g.geo_key,

        coalesce(ct.crime_rank, 0) as crime_tier,
        coalesce(ct.income_rank, 0) as income_tier,
        coalesce(ct.population_rank, 0) as population_tier,
        coalesce(ct.final_rank, 0) as composite_tier
    from businesses as b
    left join county_tiers as ct
        on lower(trim(b.principal_county)) = lower(trim(ct.county))
    left join dim_geo as g
        on lower(trim(b.principal_county)) = lower(trim(g.county_name))
),

final as (
    select
        business_key,
        entity_id,
        entity_name,
        principal_city,
        principal_county,
        principal_zip,
        entity_type,
        formation_date,
        geo_key,
        crime_tier,
        income_tier,
        population_tier,
        round(composite_tier) as composite_tier,
        coalesce(round(composite_tier) >= 3, false) as qualifies_for_subsidy,
        case round(composite_tier)
            when 4 then 'Tier 4 - Maximum Subsidy'
            when 3 then 'Tier 3 - Enhanced Subsidy'
            when 2 then 'Tier 2 - Standard Subsidy'
            when 1 then 'Tier 1 - Basic Review'
            else 'Unranked'
        end as subsidy_tier_label,
        -- Notification eligibility: active business that qualifies
        coalesce(qualifies_for_subsidy = true, false) as notification_eligible
    from joined
    where composite_tier > 0   -- exclude businesses with no county match
)

select * from final
