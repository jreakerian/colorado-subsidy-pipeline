
    
    

select
    geo_key as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.gold.dim_geography
where geo_key is not null
group by geo_key
having count(*) > 1


