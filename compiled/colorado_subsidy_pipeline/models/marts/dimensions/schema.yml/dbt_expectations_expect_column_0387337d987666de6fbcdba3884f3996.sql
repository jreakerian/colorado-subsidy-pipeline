






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and month >= 1 and month <= 12
)
 as expression


    from COLORADO_CRIME_DB_DEV.gold.dim_date
    

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







