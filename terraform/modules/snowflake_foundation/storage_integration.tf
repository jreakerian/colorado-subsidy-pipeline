# Storage integration — connects Snowflake to AWS S3.
# Uses the shared SnowflakeIntegrationRole. Allows access to the general-purpose
# project bucket (raw CSV/Parquet uploads).
#
# NOTE: Migrated from deprecated snowflake_storage_integration → snowflake_storage_integration_aws
# (v2.x — storage_provider is implicit in the resource type; storage_blocked_locations removed).
# State migration commands to run ONCE after terraform init -upgrade:
#   terraform state rm 'module.snowflake_foundation.snowflake_storage_integration.s3_integration'
#   terraform import 'module.snowflake_foundation.snowflake_storage_integration_aws.s3_integration' S3_INTEGRATION
resource "snowflake_storage_integration_aws" "s3_integration" {
  name                      = "S3_INTEGRATION"
  storage_provider          = "S3"
  storage_aws_role_arn      = var.role_arn
  enabled                   = true
  storage_allowed_locations = [
    "s3://${var.general_purpose_bucket}/"
  ]
  comment = "Storage integration for Colorado Subsidy pipeline (general-purpose bucket)"
}
