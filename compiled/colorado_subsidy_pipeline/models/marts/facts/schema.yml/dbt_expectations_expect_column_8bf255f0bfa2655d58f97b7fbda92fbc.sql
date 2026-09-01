






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and crime_count >= 1 and crime_count <= 1
)
 as expression


    from COLORADO_CRIME_DB_DEV.gold.fct_crimes
    

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







