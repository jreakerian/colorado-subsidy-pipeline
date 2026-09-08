# CSV file format — must be created BEFORE the stage that references it.
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

# External stage for raw CSV data (points to the general-purpose project bucket).
resource "snowflake_stage_external_s3" "raw_csv_stage" {
  name                = "RAW_CSV_STAGE"
  database            = snowflake_database.colorado_crime_db.name
  schema              = snowflake_schema.raw.name
  url                 = "s3://${var.general_purpose_bucket}/"
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
