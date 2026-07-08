# External Volume — Snowflake Iceberg storage backed by the S3 Tables bucket.
# Uses the shared SnowflakeIntegrationRole (same role as the storage integration).
# depends_on: storage_integration must exist first so AWS trust relationship is
# established before Snowflake tries to validate the external volume's role ARN.
resource "snowflake_external_volume" "iceberg_volume" {
  name         = "S3_ICEBERG_VOLUME"
  allow_writes = true

  storage_location {
    storage_location_name = "s3_table_bucket_location"
    storage_provider      = "S3"
    storage_base_url      = "s3://${var.table_bucket_name}/"
    storage_aws_role_arn  = var.role_arn
  }

  comment = "Iceberg external volume backed by the S3 Tables bucket (Silver + Gold namespaces)"

  depends_on = [snowflake_storage_integration.s3_integration]
}
