
    
    

select
    county_name as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_PROD.silver.crime_tier_county_rank
where county_name is not null
group by county_name
having count(*) > 1


