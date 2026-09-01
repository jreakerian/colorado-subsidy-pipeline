






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and income_percentile >= 0 and income_percentile <= 1
)
 as expression


    from COLORADO_CRIME_DB_DEV.silver.income_tier
    

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







