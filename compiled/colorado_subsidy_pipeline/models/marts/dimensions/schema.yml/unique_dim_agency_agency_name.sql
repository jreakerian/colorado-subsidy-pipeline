
    
    

select
    agency_name as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.gold.dim_agency
where agency_name is not null
group by agency_name
having count(*) > 1


