

with crime_rank as (
    select
        county_name as county,
        overall_crime_tier as crime_rank
    from COLORADO_CRIME_DB_DEV.silver.crime_tier_county_rank
    where overall_crime_tier > 0
),

income_rank as (
    select
        county,
        income_tier as income_rank
    from COLORADO_CRIME_DB_DEV.silver.income_tier
    where income_tier > 0
),

population_rank as (
    select
        county,
        crime_per_capita_tier as population_rank
    from COLORADO_CRIME_DB_DEV.silver.population_crime_per_capita_tier
    where crime_per_capita_tier > 0
),

combined as (
    select
        coalesce(c.county, replace(i.county, ' County', ''), p.county) as county,
        coalesce(c.crime_rank, 0) as crime_rank,
        coalesce(i.income_rank, 0) as income_rank,
        coalesce(p.population_rank, 0) as population_rank
    from crime_rank as c
    full outer join income_rank as i
        on lower(c.county) = replace(lower(i.county), ' county', '')
    full outer join population_rank as p
        on coalesce(lower(c.county), replace(lower(i.county), ' county', '')) = lower(p.county)
),

final as (
    select
        county,
        crime_rank,
        income_rank,
        population_rank,
        round(
            (crime_rank + income_rank + population_rank)
            / nullif(
                (
                    case when crime_rank > 0 then 1 else 0 end
                    + case when income_rank > 0 then 1 else 0 end
                    + case when population_rank > 0 then 1 else 0 end
                ),
                0
            )
        ) as final_rank
    from combined
)

select * from final