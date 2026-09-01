






    with grouped_expression as (
    select
        
        
    
  
( 1=1 and composite_tier >= 1 and composite_tier <= 4
)
 as expression


    from COLORADO_CRIME_DB_DEV.gold.fct_business_subsidy_tiers
    

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







