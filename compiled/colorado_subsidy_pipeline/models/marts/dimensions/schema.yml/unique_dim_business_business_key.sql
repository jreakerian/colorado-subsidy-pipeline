
    
    

select
    business_key as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.gold.dim_business
where business_key is not null
group by business_key
having count(*) > 1


