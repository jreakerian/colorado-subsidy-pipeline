
    
    

select
    pub_agency_name as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_PROD.PUBLIC.agency_city_mapping
where pub_agency_name is not null
group by pub_agency_name
having count(*) > 1


