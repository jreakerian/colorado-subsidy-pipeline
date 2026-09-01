
    
    

select
    entity_id as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.gold.rpt_business_tier_lookup
where entity_id is not null
group by entity_id
having count(*) > 1


