
    
    

with all_values as (

    select
        crime_against as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_DEV.silver.int_crimes_unified
    group by crime_against

)

select *
from all_values
where value_field not in (
    'Property','Person','Society'
)


