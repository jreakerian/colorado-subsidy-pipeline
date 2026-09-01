
    
    

with all_values as (

    select
        season as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_DEV.silver.int_crimes_unified
    group by season

)

select *
from all_values
where value_field not in (
    'winter','spring','summer','fall'
)


