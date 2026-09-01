
    
    

select
    agency_key as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.gold.dim_agency
where agency_key is not null
group by agency_key
having count(*) > 1


