






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and incident_month >= 1 and incident_month <= 12
)
 as expression


    from COLORADO_CRIME_DB_DEV.silver.int_crimes_unified
    

),
validation_errors as (

    select
        *
    from
        grouped_expression
    where
        not(expression = true)

)

select *
from validation_errors







