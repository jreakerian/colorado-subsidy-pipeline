
    
    

with all_values as (

    select
        state as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_PROD.gold.dim_geography
    group by state

)

select *
from all_values
where value_field not in (
    'Colorado'
)


