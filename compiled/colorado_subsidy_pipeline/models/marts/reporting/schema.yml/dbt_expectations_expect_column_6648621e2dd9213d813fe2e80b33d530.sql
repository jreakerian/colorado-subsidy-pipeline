






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and composite_tier >= 1 and composite_tier <= 4
)
 as expression


    from COLORADO_CRIME_DB_DEV.gold.rpt_business_tier_lookup
    

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







