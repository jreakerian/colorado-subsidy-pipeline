

with crimes_1997_2015 as (
    select * from COLORADO_CRIME_DB_DEV.raw.stg_colorado_crimes_1997_2015
    where
        crime_against in ('Property', 'Person', 'Society')
        and incident_date is not null
        and county_name is not null
        and lower(trim(county_name)) != 'not specified'
        and agency_name is not null
),

crimes_2016_2020 as (
    select * from COLORADO_CRIME_DB_DEV.raw.stg_colorado_crimes_2016_2020
    where
        crime_against in ('Property', 'Person', 'Society')
        and incident_date is not null
        and county_name is not null
        and lower(trim(county_name)) != 'not specified'
        and agency_name is not null
),

unioned_raw as (
    select
        agency_name,
        null as agency_type_name,   -- not present in 2016-2020; pad 1997-2015 too for parity
        null as city_name,           -- not reliably present; resolved via dim_geography
        county_name,
        incident_date,
        incident_hour,
        offense_name,
        crime_against,
        offense_category_name,
        null as offense_group,       -- only in 2016-2020
        age_num,
        source_period
    from crimes_1997_2015

    union all

    select
        agency_name,
        null as agency_type_name,
        null as city_name,
        county_name,
        incident_date,
        incident_hour,
        offense_name,
        crime_against,
        offense_category_name,
        offense_group,
        age_num,
        source_period
    from crimes_2016_2020
),

normalized as (
    select
        incident_date,

        incident_hour,

        crime_against,
        offense_category_name,
        -- Offense name: sentence-case
        offense_group,
        age_num,
        source_period,
        trim(regexp_replace(
            regexp_replace(regexp_replace(regexp_replace(
                agency_name,
                '\\bDrug Enforcement Team\\b', 'Drug Task Force', 1, 0, 'i'
            ),
            '\\s+Police Department\\b', '', 1, 0, 'i'),
            '\\s+County Sheriff(''s Office)?\\b', '', 1, 0, 'i'),
            '\\s+Sheriff(''s Office)?\\b', '', 1, 0, 'i'
        )) as agency_name,
        case
            when county_name not like '%;%' and county_name not like '%,%'
                then lower(trim(county_name))
            else array_to_string(
                array_sort(transform(
                    split(regexp_replace(lower(trim(county_name)), ';', ','), ','),
                    x -> trim(x)
                )), ', '
            )
        end as county_name,
        initcap(lower(trim(offense_name))) as offense_name
    from unioned_raw
),

final as (
    select
        agency_name,
        county_name,
        incident_date,
        incident_hour,
        offense_name,
        crime_against,
        offense_category_name,
        offense_group,
        age_num,
        source_period,
        date_part('year', incident_date) as incident_year,
        date_part('month', incident_date) as incident_month,
        date_part('day', incident_date) as incident_day,
        -- 1=Sunday, 7=Saturday (Snowflake DOW returns 0-6, shift by +1)
        date_part('dow', incident_date) + 1 as day_of_week,
        iff(incident_hour between 6 and 17, 'day', 'night') as time_of_day,
        case date_part('month', incident_date)
            when 12 then 'winter' when 1 then 'winter' when 2 then 'winter'
            when 3 then 'spring' when 4 then 'spring' when 5 then 'spring'
            when 6 then 'summer' when 7 then 'summer' when 8 then 'summer'
            else 'fall'
        end as season
    from normalized
)

select * from final