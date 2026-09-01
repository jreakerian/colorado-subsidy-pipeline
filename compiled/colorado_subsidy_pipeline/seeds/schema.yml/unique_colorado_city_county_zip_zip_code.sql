
    
    

select
    zip_code as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.PUBLIC.colorado_city_county_zip
where zip_code is not null
group by zip_code
having count(*) > 1


