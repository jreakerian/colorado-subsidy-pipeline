

with source as (
    select * from COLORADO_CRIME_DB_DEV.RAW.colorado_business_entities
),

cleaned as (
    select
        entityid as entity_id,
        entityname as entity_name,
        principaladdress1 as principal_address_1,
        principaladdress2 as principal_address_2,
        principalcity as principal_city,
        principalstate as principal_state,
        principalzipcode as principal_zip_code,
        principalcountry as principal_country,
        entitystatus as entity_status,
        jurisdictonofformation as jurisdiction_of_formation,
        entitytype as entity_type,
        cast(entityformdate as date) as entity_form_date
    from source
    where principalstate = 'CO'   -- structural: limit to Colorado records only
)

select * from cleaned