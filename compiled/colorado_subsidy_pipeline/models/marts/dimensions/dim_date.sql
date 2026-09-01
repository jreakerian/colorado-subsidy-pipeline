

-- Generate one row per date from 1997-01-01 to 2020-12-31
with date_spine as (
  





with rawdata as (

    

    

    with p as (
        select 0 as generated_number union all select 1
    ), unioned as (

    select

    
    p0.generated_number * power(2, 0)
     + 
    
    p1.generated_number * power(2, 1)
     + 
    
    p2.generated_number * power(2, 2)
     + 
    
    p3.generated_number * power(2, 3)
     + 
    
    p4.generated_number * power(2, 4)
     + 
    
    p5.generated_number * power(2, 5)
     + 
    
    p6.generated_number * power(2, 6)
     + 
    
    p7.generated_number * power(2, 7)
     + 
    
    p8.generated_number * power(2, 8)
     + 
    
    p9.generated_number * power(2, 9)
     + 
    
    p10.generated_number * power(2, 10)
     + 
    
    p11.generated_number * power(2, 11)
     + 
    
    p12.generated_number * power(2, 12)
     + 
    
    p13.generated_number * power(2, 13)
    
    
    + 1
    as generated_number

    from

    
    p as p0
     cross join 
    
    p as p1
     cross join 
    
    p as p2
     cross join 
    
    p as p3
     cross join 
    
    p as p4
     cross join 
    
    p as p5
     cross join 
    
    p as p6
     cross join 
    
    p as p7
     cross join 
    
    p as p8
     cross join 
    
    p as p9
     cross join 
    
    p as p10
     cross join 
    
    p as p11
     cross join 
    
    p as p12
     cross join 
    
    p as p13
    
    

    )

    select *
    from unioned
    where generated_number <= 10227
    order by generated_number



),

all_periods as (

    select (
        

    dateadd(
        day,
        row_number() over (order by generated_number) - 1,
        cast('01/01/1997' as date)
        )


    ) as date_day
    from rawdata

),

filtered as (

    select *
    from all_periods
    where date_day <= cast('01/01/2025' as date)

)

select * from filtered


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