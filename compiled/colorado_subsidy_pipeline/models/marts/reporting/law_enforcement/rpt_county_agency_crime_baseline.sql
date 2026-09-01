

-- KPI: Set a 5% crime reduction goal per police agency per county.
-- Thin wrapper over fct_crimes + dim_agency.
with crimes as (
    select * from COLORADO_CRIME_DB_DEV.gold.fct_crimes
),

agency as (
    select * from COLORADO_CRIME_DB_DEV.gold.dim_agency
)

select
    a.primary_county as county_name,
    a.agency_name,
    count(*) as total_crimes,
    round(count(*) * 0.95) as target_crimes_5pct_reduction,
    min(c.incident_date) as first_incident_date,
    max(c.incident_date) as last_incident_date
from crimes as c
inner join agency as a on c.agency_key = a.agency_key
group by a.primary_county, a.agency_name