
    
    

with all_values as (

    select
        income_tier as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_DEV.silver.income_tier
    group by income_tier

)

select *
from all_values
where value_field not in (
    '1','2','3','4'
)


