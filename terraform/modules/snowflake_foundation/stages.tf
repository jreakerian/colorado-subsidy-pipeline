# CSV file format — must be created BEFORE the stage that references it
resource "snowflake_file_format" "csv_format" {
  name                = "CSV_FORMAT"
  database            = snowflake_database.colorado_crime_db.name
  schema              = snowflake_schema.raw.name
  format_type         = "CSV"
  compression         = "AUTO"
  field_delimiter     = ","
  record_delimiter    = "\n"
  skip_header         = 1
  null_if             = ["NULL", "null", ""]
  empty_field_as_null = true
  comment             = "CSV file format for raw data ingestion"

  depends_on = [snowflake_schema.raw]
}

# Parquet file format
resource "snowflake_file_format" "parquet_format" {
  name        = "PARQUET_FORMAT"
  database    = snowflake_database.colorado_crime_db.name
  schema      = snowflake_schema.raw.name
  format_type = "PARQUET"
  compression = "AUTO"
  comment     = "Parquet file format for efficient storage"

  depends_on = [snowflake_schema.raw]
}

# External stage for raw CSV data (points to the general-purpose project bucket).
# depends_on ensures:
#   1. csv_format exists before Snowflake creates the stage (file_format is a string attr)
#   2. storage_integration exists so the stage can authenticate to S3
resource "snowflake_stage" "raw_csv_stage" {
  name                = "RAW_CSV_STAGE"
  database            = snowflake_database.colorado_crime_db.name
  schema              = snowflake_schema.raw.name
  url                 = "s3://${var.general_purpose_bucket}/raw/"
  storage_integration = snowflake_storage_integration.s3_integration.name
  file_format         = "FORMAT_NAME = \"${snowflake_database.colorado_crime_db.name}\".\"${snowflake_schema.raw.name}\".\"${snowflake_file_format.csv_format.name}\""
  comment             = "External stage for raw CSV data from the general-purpose project bucket"

  depends_on = [
    snowflake_file_format.csv_format,
    snowflake_storage_integration.s3_integration,
  ]
}