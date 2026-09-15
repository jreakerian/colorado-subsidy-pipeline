
    
    

with all_values as (

    select
        time_of_day as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_PROD.gold.rpt_city_time_of_day_crimes
    group by time_of_day

)

select *
from all_values
where value_field not in (
    'day','night'
)


