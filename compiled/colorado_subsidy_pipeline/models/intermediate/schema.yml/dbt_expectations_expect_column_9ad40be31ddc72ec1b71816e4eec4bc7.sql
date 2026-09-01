






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and final_rank >= 1 and final_rank <= 4
)
 as expression


    from COLORADO_CRIME_DB_DEV.silver.final_county_tier_rank
    

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







