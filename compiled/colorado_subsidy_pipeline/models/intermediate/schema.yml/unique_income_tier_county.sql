
    
    

select
    county as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_PROD.silver.income_tier
where county is not null
group by county
having count(*) > 1


