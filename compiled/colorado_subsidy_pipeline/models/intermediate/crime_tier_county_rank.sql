

with crime_tiers as (
    select * from COLORADO_CRIME_DB_DEV.silver.crime_tiers
)

select
    county_name,
    max(
        case
            when offense_category_name = 'Destruction/Damage/Vandalism of Property' then crime_tier
        end
    ) as property_destruction_tier,
    max(case when offense_category_name = 'Burglary/Breaking & Entering' then crime_tier end)
        as burglary_tier,
    max(case when offense_category_name = 'Larceny/Theft Offenses' then crime_tier end)
        as larceny_theft_tier,
    max(case when offense_category_name = 'Motor Vehicle Theft' then crime_tier end)
        as vehicle_theft_tier,
    max(case when offense_category_name = 'Robbery' then crime_tier end) as robbery_tier,
    max(case when offense_category_name = 'Arson' then crime_tier end) as arson_tier,
    max(case when offense_category_name = 'Stolen Property Offenses' then crime_tier end)
        as stolen_property_tier,
    round(avg(crime_tier)) as overall_crime_tier
from crime_tiers
group by county_name