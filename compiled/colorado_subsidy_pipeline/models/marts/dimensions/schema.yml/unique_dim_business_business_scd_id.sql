
    
    

select
    business_scd_id as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.gold.dim_business
where business_scd_id is not null
group by business_scd_id
having count(*) > 1


