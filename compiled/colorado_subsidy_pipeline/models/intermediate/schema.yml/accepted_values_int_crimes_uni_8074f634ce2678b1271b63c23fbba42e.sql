
    
    

with all_values as (

    select
        source_period as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_DEV.silver.int_crimes_unified
    group by source_period

)

select *
from all_values
where value_field not in (
    '1997_2015','2016_2020'
)


