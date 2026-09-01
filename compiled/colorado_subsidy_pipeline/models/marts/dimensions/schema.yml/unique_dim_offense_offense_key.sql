
    
    

select
    offense_key as unique_field,
    count(*) as n_records

from COLORADO_CRIME_DB_DEV.gold.dim_offense
where offense_key is not null
group by offense_key
having count(*) > 1


