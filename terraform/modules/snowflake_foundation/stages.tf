# CSV file format — must be created BEFORE the stage that references it.
# Migrated from deprecated snowflake_file_format → snowflake_file_format_csv (v2.19 preview).
# State migration commands to run ONCE after terraform init -upgrade:
#   terraform state rm 'module.snowflake_foundation.snowflake_file_format.csv_format'
#   terraform import 'module.snowflake_foundation.snowflake_file_format_csv.csv_format' "\"<DB_NAME>\".\"RAW\".\"CSV_FORMAT\""
resource "snowflake_file_format_csv" "csv_format" {
  name                = "CSV_FORMAT"
  database            = snowflake_database.colorado_crime_db.name
  schema              = snowflake_schema.raw.name
  compression         = "AUTO"
  field_delimiter     = ","
  record_delimiter    = "\n"
  skip_header         = 1
  null_if             = ["NULL", "null", ""]
  empty_field_as_null = true
  comment             = "CSV file format for raw data ingestion"

  depends_on = [snowflake_schema.raw]
}

# Parquet file format.
# Migrated from deprecated snowflake_file_format → snowflake_file_format_parquet (v2.19 preview).
# State migration commands to run ONCE after terraform init -upgrade:
#   terraform state rm 'module.snowflake_foundation.snowflake_file_format.parquet_format'
#   terraform import 'module.snowflake_foundation.snowflake_file_format_parquet.parquet_format' "\"<DB_NAME>\".\"RAW\".\"PARQUET_FORMAT\""
resource "snowflake_file_format_parquet" "parquet_format" {
  name        = "PARQUET_FORMAT"
  database    = snowflake_database.colorado_crime_db.name
  schema      = snowflake_schema.raw.name
  compression = "AUTO"
  comment     = "Parquet file format for efficient storage"

  depends_on = [snowflake_schema.raw]
}

# External stage for raw CSV data (points to the general-purpose project bucket).
# Migrated from deprecated snowflake_stage → snowflake_stage_external_s3 (stable in v2.18+).
# file_format is now a nested block (not a raw string attribute).
# State migration commands to run ONCE after terraform init -upgrade:
#   terraform state rm 'module.snowflake_foundation.snowflake_stage.raw_csv_stage'
#   terraform import 'module.snowflake_foundation.snowflake_stage_external_s3.raw_csv_stage' "\"<DB_NAME>\".\"RAW\".\"RAW_CSV_STAGE\""
resource "snowflake_stage_external_s3" "raw_csv_stage" {
  name                = "RAW_CSV_STAGE"
  database            = snowflake_database.colorado_crime_db.name
  schema              = snowflake_schema.raw.name
  url                 = "s3://${var.general_purpose_bucket}/raw/"
  storage_integration = snowflake_storage_integration_aws.s3_integration.name
  directory {
    enable = true
  }
  comment = "External stage for raw CSV data from the general-purpose project bucket"

  file_format {
    format_name = "\"${snowflake_database.colorado_crime_db.name}\".\"${snowflake_schema.raw.name}\".\"${snowflake_file_format_csv.csv_format.name}\""
  }

  depends_on = [
    snowflake_file_format_csv.csv_format,
    snowflake_storage_integration_aws.s3_integration,
  ]
}
