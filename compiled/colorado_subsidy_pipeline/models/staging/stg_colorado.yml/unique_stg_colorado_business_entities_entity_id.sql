
    
    

select
    entity_id as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.raw.stg_colorado_business_entities
where entity_id is not null
group by entity_id
having count(*) > 1


