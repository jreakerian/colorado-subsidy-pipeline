
    
    

with all_values as (

    select
        crime_per_capita_tier as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_DEV.silver.population_crime_per_capita_tier
    group by crime_per_capita_tier

)

select *
from all_values
where value_field not in (
    '1','2','3','4'
)


