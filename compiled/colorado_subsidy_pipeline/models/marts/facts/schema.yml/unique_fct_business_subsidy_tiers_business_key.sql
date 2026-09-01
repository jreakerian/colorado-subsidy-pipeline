
    
    

select
    business_key as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.gold.fct_business_subsidy_tiers
where business_key is not null
group by business_key
having count(*) > 1


