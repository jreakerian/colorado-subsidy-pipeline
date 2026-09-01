
    
    

select
    county as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.silver.final_county_tier_rank
where county is not null
group by county
having count(*) > 1


