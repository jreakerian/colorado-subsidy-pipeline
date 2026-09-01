






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and age_num >= 0 and age_num <= 120
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







