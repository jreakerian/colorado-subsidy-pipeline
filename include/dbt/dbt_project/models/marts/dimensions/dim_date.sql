{{
  config(
    materialized='table',
    tags=['marts', 'dimension'],
    meta={
      'owner': 'analytics',
      'tier': 'marts',
      'description': 'Date dimension spanning project range 1997-2020.'
    }
  )
}}

-- Generate one row per date from 1997-01-01 to 2020-12-31
with date_spine as (
  {{ dbt_utils.date_spine(
      datepart='day',
      start_date="cast('01/01/1997' as date)",
      end_date="cast('01/01/2025' as date)"
  ) }}
),

final as (
    select
        cast(date_day as date) as date_day,
        to_char(cast(date_day as date), 'MM/DD/YYYY') as full_date,
        to_char(date_day, 'MM/DD/YYYY') as date_key,
        year(date_day) as year,
        quarter(date_day) as quarter,
        month(date_day) as month,
        case month(date_day)
            when 1 then 'January' when 2 then 'February'
            when 3 then 'March' when 4 then 'April'
            when 5 then 'May' when 6 then 'June'
            when 7 then 'July' when 8 then 'August'
            when 9 then 'September' when 10 then 'October'
            when 11 then 'November' when 12 then 'December'
        end as month_name,
        day(date_day) as day_of_month,
        -- 1=Sunday, 7=Saturday (Snowflake DAYOFWEEK returns 0-6, shift by +1)
        dayofweek(date_day) + 1 as day_of_week,
        case dayofweek(date_day) + 1
            when 1 then 'Sunday' when 2 then 'Monday'
            when 3 then 'Tuesday' when 4 then 'Wednesday'
            when 5 then 'Thursday' when 6 then 'Friday'
            when 7 then 'Saturday'
        end as day_name,
        dayofyear(date_day) as day_of_year,
        weekofyear(date_day) as week_of_year,
        case
            when month(date_day) in (12, 1, 2) then 'winter'
            when month(date_day) in (3, 4, 5) then 'spring'
            when month(date_day) in (6, 7, 8) then 'summer'
            else 'fall'
        end as season,
        coalesce(dayofweek(date_day) + 1 in (1, 7), false) as is_weekend
    from date_spine
)

select * from final
