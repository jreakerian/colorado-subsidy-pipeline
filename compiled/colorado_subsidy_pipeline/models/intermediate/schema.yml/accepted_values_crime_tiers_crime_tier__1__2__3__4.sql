
    
    

with all_values as (

    select
        crime_tier as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_DEV.silver.crime_tiers
    group by crime_tier

)

select *
from all_values
where value_field not in (
    '1','2','3','4'
)


