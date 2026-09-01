

with source as (
    select * from COLORADO_CRIME_DB_DEV.RAW.colorado_crimes_2016_2020
),

cleaned as (
    select
        pub_agency_name as agency_name,
        county_name,
        cast(try_to_date(incident_date, 'MM/DD/YYYY') as date) as incident_date,
        cast(incident_hour as integer) as incident_hour,
        offense_name,
        crime_against,
        offense_category_name,
        offense_group,
        cast(age_num as integer) as age_num,
        '2016_2020' as source_period
    from source
)

select * from cleaned
where
    -- Exclude statewide agencies (State Patrol, CBI) that have no county assignment.
    -- These agencies operate across all of Colorado and cannot be attributed to a single county.
    county_name is not null
    -- Exclude fully anonymous records missing agency, offense category, and date simultaneously.
    -- These are orphan rows in the source with no useful dimensional context (461 rows).
    and not (agency_name is null and offense_category_name is null and incident_date is null)
    -- Exclude records with no incident date — no date means the record cannot be used
    -- for any time-based analysis or KPI.
    and incident_date is not null