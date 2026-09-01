

with crimes as (
    select * from COLORADO_CRIME_DB_DEV.silver.int_crimes_unified
),


-- If an agency appears with multiple counties (multi-jurisdiction),
-- take their most frequently recorded county as the primary
agency_ranked as (
    select
        agency_name,
        county_name,
        count(*) as record_count,
        row_number() over (partition by agency_name order by count(*) desc) as rn
    from crimes
    group by agency_name, county_name
),

final as (
    select
        agency_name,
        county_name as primary_county,
        row_number() over (order by agency_name) as agency_key
    from agency_ranked
    where
        rn = 1
        and agency_name is not null
)

select * from final