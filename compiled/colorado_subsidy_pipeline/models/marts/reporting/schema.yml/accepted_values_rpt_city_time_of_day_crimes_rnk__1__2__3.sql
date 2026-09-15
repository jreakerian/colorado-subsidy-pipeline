
    
    

with all_values as (

    select
        rnk as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_PROD.gold.rpt_city_time_of_day_crimes
    group by rnk

)

select *
from all_values
where value_field not in (
    '1','2','3'
)


