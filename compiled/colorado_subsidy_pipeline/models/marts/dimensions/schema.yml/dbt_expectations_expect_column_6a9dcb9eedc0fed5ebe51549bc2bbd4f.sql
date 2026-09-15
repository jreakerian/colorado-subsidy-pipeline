






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and day_of_week >= 1 and day_of_week <= 7
)
 as expression


    from COLORADO_CRIME_DB_PROD.gold.dim_date
    

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







