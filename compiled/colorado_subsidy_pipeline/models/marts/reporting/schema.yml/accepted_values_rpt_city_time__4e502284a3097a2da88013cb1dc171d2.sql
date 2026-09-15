
    
    

with all_values as (

    select
        crime_against as value_field,
        count(*) as n_records

    from COLORADO_CRIME_DB_PROD.gold.rpt_city_time_of_day_crimes
    group by crime_against

)

select *
from all_values
where value_field not in (
    'Property','Person','Society'
)


