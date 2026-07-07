# Storage integration — connects Snowflake to AWS S3.
# Uses the shared SnowflakeIntegrationRole. Allows access to the general-purpose
# project bucket (raw CSV/Parquet uploads) and the S3 Tables bucket (Iceberg).
resource "snowflake_storage_integration" "s3_integration" {
  name                      = "S3_INTEGRATION"
  storage_provider          = "S3"
  storage_aws_role_arn      = var.role_arn
  enabled                   = true
  storage_allowed_locations = [
    "s3://${var.general_purpose_bucket}/",
    "s3://${var.table_bucket_name}/"
  ]
  storage_blocked_locations = []
  comment                   = "Storage integration for Colorado Subsidy pipeline (general-purpose bucket + S3 Tables bucket)"
}
