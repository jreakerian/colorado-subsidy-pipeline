

with crimes as (
    select * from COLORADO_CRIME_DB_DEV.silver.int_crimes_unified
),

county_crime_counts as (
    select
        county_name,
        offense_category_name,
        count(*) as total_crimes
    from crimes
    where
        offense_category_name in (
            'Destruction/Damage/Vandalism of Property', 'Burglary/Breaking & Entering', 'Larceny/Theft Offenses', 'Motor Vehicle Theft', 'Robbery', 'Arson', 'Stolen Property Offenses'
        )
    group by county_name, offense_category_name
),

percentile_ranked as (
    select
        county_name,
        offense_category_name,
        total_crimes,
        percent_rank()
            over (partition by offense_category_name order by total_crimes)
            as crime_percentile
    from county_crime_counts
)

select
    county_name,
    offense_category_name,
    total_crimes,
    crime_percentile,
    case
        when crime_percentile >= 0.75 then 4
        when crime_percentile >= 0.50 then 3
        when crime_percentile >= 0.25 then 2
        else 1
    end as crime_tier
from percentile_ranked