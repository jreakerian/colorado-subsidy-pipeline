# External Volume — Snowflake-managed Iceberg storage backed by the general-purpose S3 bucket.
#
# WHY NOT S3 TABLES:
#   AWS S3 Tables uses the Iceberg REST API protocol (not the standard s3:// API).
#   Snowflake's CATALOG = 'SNOWFLAKE' mode requires a standard S3 bucket reachable
#   via s3:// URLs. S3 Tables are not reachable this way and will return:
#   "S3 bucket '<name>' does not exist or not authorized."
#
#   For S3 Tables integration see docs/path_b_s3_tables_iceberg_rest.md.
#
# Uses the shared SnowflakeIntegrationRole (same role as the storage integration).
# depends_on: storage_integration must exist first so the AWS trust relationship is
# established before Snowflake tries to validate the external volume's role ARN.
resource "snowflake_external_volume" "iceberg_volume" {
  name         = "S3_ICEBERG_VOLUME"
  allow_writes = true

  storage_location {
    storage_location_name = "general_purpose_iceberg_location"
    storage_provider      = "S3"
    # iceberg/ prefix keeps Iceberg metadata & Parquet files separate from raw
    # uploads and other artefacts that live in the root of the same bucket.
    storage_base_url     = "s3://${var.general_purpose_bucket}/iceberg/"
    storage_aws_role_arn = var.role_arn
  }

  comment = "Snowflake-managed Iceberg external volume backed by the general-purpose project bucket (iceberg/ prefix)"

  depends_on = [snowflake_storage_integration.s3_integration]
}
