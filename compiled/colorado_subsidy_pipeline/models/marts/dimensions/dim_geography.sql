


with city_county_zip as (
    select * from COLORADO_CRIME_DB_PROD.raw.stg_colorado_city_county_zip
),

county_coordinates as (
    select * from COLORADO_CRIME_DB_PROD.raw.stg_colorado_county_boundaries
),

-- City-level rows: one row per city+county combination from zip lookup,
-- enriched with centroid coordinates from the county boundaries seed.
city_rows as (
    select
        ccz.city                            as city_name,
        ccz.county                          as county_name,
        ccz.zip_code,
        co.cent_lat,
        co.cent_long
    from city_county_zip as ccz
    -- stg_colorado_city_county_zip outputs lower(county); stg_colorado_county_boundaries
    -- outputs county_label (title-case). Lower both sides for a reliable join.
    left join county_coordinates as co
        on ccz.county = lower(trim(co.county_label))
),

-- County-only rows: one row per county for crimes that carry only county
-- (no city). Used as the geo grain for all county-level KPIs.
county_only_rows as (
    select
        '[County Level]'            as city_name,
        null                        as zip_code,
        co.cent_lat,
        co.cent_long,
        lower(trim(co.county_label)) as county_name
    from county_coordinates as co
),

combined as (
    select
        city_name,
        county_name,
        zip_code,
        cent_lat,
        cent_long
    from city_rows
    union distinct
    select
        city_name,
        county_name,
        zip_code,
        cent_lat,
        cent_long
    from county_only_rows
),

final as (
    select
        city_name,
        county_name,
        zip_code,
        cent_lat,
        cent_long,
        'Colorado' as state,
        row_number() over (
            order by county_name, city_name nulls last, zip_code nulls last
        ) as geo_key
    from combined
)

select * from final