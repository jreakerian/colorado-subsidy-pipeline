{{
  config(
    materialized='table',
    tags=['intermediate', 'core'],
    meta={
      'owner': 'data-engineering',
      'tier': 'intermediate',
      'pii': false,
      'description': 'Unified, normalized crime incidents from 1997-2020. Single source of truth for all crime fact models.'
    }
  )
}}

with crimes_1997_2015 as (
  select * from {{ ref('stg_colorado_crimes_1997_2015') }}
),

crimes_2016_2020 as (
  select * from {{ ref('stg_colorado_crimes_2016_2020') }}
),

unioned_raw as (
  select
    agency_name,
    null          as agency_type_name,   -- not present in 2016-2020; pad 1997-2015 too for parity
    null          as city_name,           -- not reliably present; resolved via dim_geography
    county_name,
    incident_date,
    incident_hour,
    offense_name,
    crime_against,
    offense_category_name,
    null          as offense_group,       -- only in 2016-2020
    age_num,
    source_period
  from crimes_1997_2015

  union all

  select
    agency_name,
    null          as agency_type_name,
    null          as city_name,
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
    trim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
      agency_name,
      '\\bDrug Enforcement Team\\b', 'Drug Task Force', 1, 0, 'i'),
      '\\s+Police Department\\b', '', 1, 0, 'i'),
      '\\s+County Sheriff(''s Office)?\\b', '', 1, 0, 'i'),
      '\\s+Sheriff(''s Office)?\\b', '', 1, 0, 'i'
    )) as agency_name,
    
    array_to_string(
      array_sort(
        transform(
          split(
            regexp_replace(regexp_replace(lower(trim(county_name)), ';', ','), '"', ''),
            ','
          ),
          x -> trim(x)
        )
      ),
      ', '
    ) as county_name,
    
    incident_date,
    incident_hour,
    -- Offense name: sentence-case
    upper(substring(lower(trim(offense_name)), 1, 1)) || lower(substring(lower(trim(offense_name)), 2)) as offense_name,

    crime_against,
    offense_category_name,
    offense_group,
    age_num,
    source_period
  from unioned_raw
  where crime_against in ('Property', 'Person', 'Society')
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
    year(incident_date)  as incident_year,
    month(incident_date) as incident_month,
    day(incident_date)   as incident_day,
    dayofweek(incident_date) as day_of_week,  -- 1=Sunday
    case
      when incident_hour between 6 and 17 then 'day'
      else 'night'
    end as time_of_day,
    case
      when month(incident_date) in (12, 1, 2) then 'winter'
      when month(incident_date) in (3, 4, 5)  then 'spring'
      when month(incident_date) in (6, 7, 8)  then 'summer'
      else 'fall'
    end as season
  from normalized
  where incident_date is not null
    and county_name   is not null
    and agency_name   is not null
)

select * from final
