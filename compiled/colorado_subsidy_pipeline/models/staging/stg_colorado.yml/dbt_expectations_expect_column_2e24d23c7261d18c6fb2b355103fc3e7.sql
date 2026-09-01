






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and total_population >= 0
)
 as expression


    from COLORADO_CRIME_DB_DEV.raw.stg_colorado_population
    

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







