






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and overall_crime_tier >= 1 and overall_crime_tier <= 4
)
 as expression


    from COLORADO_CRIME_DB_PROD.silver.crime_tier_county_rank
    

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







