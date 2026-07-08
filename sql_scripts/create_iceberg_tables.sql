CREATE ICEBERG TABLE COLORADO_CRIME_DB.BRONZE.COLORADO_CRIMES_1997_2015_RAW (
    pub_agency_name STRING,
    county_name STRING,
    incident_date STRING,
    incident_hour INTEGER,
    offense_name STRING,
    crime_against STRING,
    offense_category_name STRING,
    offense_group STRING,
    age_num INTEGER
)
EXTERNAL_VOLUME = S3_ICEBERG_VOLUME
BASE_LOCATION = 'raw/crimes-1997-2015'
CATALOG = 'SNOWFLAKE'
CATALOG_NAMESPACE = 'COLORADO_CRIME_DB'
CATALOG_TABLENAME = 'COLORADO_CRIMES_1997_2015_RAW'
COMMENT = 'Iceberg table for Colorado crimes 1997-2015';

CREATE ICEBERG TABLE COLORADO_CRIME_DB.BRONZE.COLORADO_BUSINESS_ENTITIES (
    entityid NUMBER,
    entityname STRING,
    principaladdress1 STRING,
    principaladdress2 STRING,
    principalcity STRING,
    principalcounty STRING,
    principalstate STRING,
    principalzipcode STRING,
    principalcountry STRING,
    entitystatus STRING,
    jurisdictonofformation STRING,
    entitytype STRING,
    entityformdate DATE
)
EXTERNAL_VOLUME = S3_ICEBERG_VOLUME
BASE_LOCATION = 'raw/business-entities'
CATALOG = 'SNOWFLAKE'
CATALOG_NAMESPACE = 'COLORADO_CRIME_DB'
CATALOG_TABLENAME = 'COLORADO_BUSINESS_ENTITIES'
COMMENT = 'Iceberg table for Colorado business entities';

-- Silver Layer: Iceberg Tables (transformation outputs)

CREATE ICEBERG TABLE COLORADO_CRIME_DB.SILVER.COLORADO_TEMP_GEOCODED_ENTITIES (
    entityid NUMBER,
    principaladdress1 STRING,
    principalcity STRING,
    principalzipcode STRING,
    full_address STRING,
    geo_city STRING,
    geo_county STRING,
    geo_state STRING,
    geo_postcode STRING
)
EXTERNAL_VOLUME = S3_ICEBERG_VOLUME
BASE_LOCATION = 'silver/geocoded-entities'
CATALOG = 'SNOWFLAKE'
CATALOG_NAMESPACE = 'COLORADO_CRIME_DB'
CATALOG_TABLENAME = 'COLORADO_TEMP_GEOCODED_ENTITIES'
COMMENT = 'Iceberg table for geocoded business entities';

CREATE ICEBERG TABLE COLORADO_CRIME_DB.SILVER.COLORADO_CRIMES_CLEANED (
    agency_name STRING,
    county_name STRING,
    incident_date DATE,
    incident_hour INTEGER,
    offense_name STRING,
    crime_against STRING,
    offense_category_name STRING,
    age_num INTEGER,
    cleaned_at TIMESTAMP_NTZ
)
EXTERNAL_VOLUME = S3_ICEBERG_VOLUME
BASE_LOCATION = 'silver/colorado_crimes_cleaned'
CATALOG = 'SNOWFLAKE'
CATALOG_NAMESPACE = 'COLORADO_CRIME_DB'
CATALOG_TABLENAME = 'COLORADO_CRIMES_CLEANED'
COMMENT = 'Cleaned crime data - transformed from raw CSV';

CREATE ICEBERG TABLE COLORADO_CRIME_DB.SILVER.COLORADO_BUSINESS_ENTITIES_CLEANED (
    entityid NUMBER,
    entityname STRING,
    principaladdress1 STRING,
    principalcity STRING,
    principalcounty STRING,
    principalstate STRING,
    principalzipcode STRING,
    entitystatus STRING,
    entitytype STRING,
    entityformdate DATE,
    cleaned_at TIMESTAMP_NTZ
)
EXTERNAL_VOLUME = S3_ICEBERG_VOLUME
BASE_LOCATION = 'silver/business_entities_cleaned'
CATALOG = 'SNOWFLAKE'
CATALOG_NAMESPACE = 'COLORADO_CRIME_DB'
CATALOG_TABLENAME = 'COLORADO_BUSINESS_ENTITIES_CLEANED'
COMMENT = 'Cleaned business entities with validated addresses';

-- -----------------------------------------------------------------------------
-- GOLD LAYER: Analytics-Ready Iceberg Tables
-- -----------------------------------------------------------------------------

CREATE ICEBERG TABLE COLORADO_CRIME_DB.GOLD.COUNTY_CRIME_AGGREGATES (
    county_name STRING,
    year INTEGER,
    month INTEGER,
    total_crimes NUMBER,
    crimes_per_100k NUMBER,
    avg_age NUMBER,
    top_offense_category STRING,
    aggregated_at TIMESTAMP_NTZ
)
EXTERNAL_VOLUME = S3_ICEBERG_VOLUME
BASE_LOCATION = 'gold/county_crime_aggregates'
CATALOG = 'SNOWFLAKE'
CATALOG_NAMESPACE = 'COLORADO_CRIME_DB'
CATALOG_TABLENAME = 'COUNTY_CRIME_AGGREGATES'
COMMENT = 'County-level crime aggregations for dashboards';

CREATE ICEBERG TABLE COLORADO_CRIME_DB.GOLD.CRIME_TIER_RANKINGS (
    county_name STRING,
    year INTEGER,
    crime_score NUMBER,
    income_score NUMBER,
    population_score NUMBER,
    overall_tier STRING,
    tier_rank NUMBER,
    calculated_at TIMESTAMP_NTZ
)
EXTERNAL_VOLUME = S3_ICEBERG_VOLUME
BASE_LOCATION = 'gold/crime_tier_rankings'
CATALOG = 'SNOWFLAKE'
CATALOG_NAMESPACE = 'COLORADO_CRIME_DB'
CATALOG_TABLENAME = 'CRIME_TIER_RANKINGS'
COMMENT = 'County tier rankings based on crime, income, and population';

CREATE ICEBERG TABLE COLORADO_CRIME_DB.GOLD.CITY_SEASONAL_CRIME_TRENDS (
    city_name STRING,
    season STRING,
    year INTEGER,
    avg_crimes_per_day NUMBER,
    peak_crime_hour INTEGER,
    top_offense_type STRING,
    trend_at TIMESTAMP_NTZ
)
EXTERNAL_VOLUME = S3_ICEBERG_VOLUME
BASE_LOCATION = 'gold/city_seasonal_trends'
CATALOG = 'SNOWFLAKE'
CATALOG_NAMESPACE = 'COLORADO_CRIME_DB'
CATALOG_TABLENAME = 'CITY_SEASONAL_CRIME_TRENDS'
COMMENT = 'City-level seasonal crime trends for Grafana dashboards';