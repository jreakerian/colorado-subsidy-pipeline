output "snowflake_role_arn" {
  description = "ARN of the shared IAM role for all Snowflake integrations (storage, external volume, API)"
  value       = aws_iam_role.snowflake_role.arn
}

output "snowflake_role_name" {
  description = "Name of the shared IAM role for all Snowflake integrations"
  value       = aws_iam_role.snowflake_role.name
}

output "api_integration_role_arn" {
  description = "ARN of the shared IAM role used for Snowflake API integration (alias of snowflake_role_arn)"
  value       = aws_iam_role.snowflake_role.arn
}

output "policy_arn" {
  description = "ARN of the IAM policy attached to the Snowflake integration role"
  value       = aws_iam_policy.lakehouse_rw_policy.arn
}

output "table_bucket_arn" {
  description = "ARN of the S3 Tables bucket (Iceberg external volume for Silver and Gold)"
  value       = aws_s3tables_table_bucket.data_lake.arn
}

output "table_bucket_name" {
  description = "Name of the S3 Tables bucket"
  value       = aws_s3tables_table_bucket.data_lake.name
}

output "general_purpose_bucket_name" {
  description = "Name of the general-purpose project S3 bucket (raw uploads, scripts, misc)"
  value       = aws_s3_bucket.general_purpose.bucket
}

output "general_purpose_bucket_arn" {
  description = "ARN of the general-purpose project S3 bucket"
  value       = aws_s3_bucket.general_purpose.arn
}

output "snowflake_external_id" {
  description = "The AWS_EXTERNAL_ID provided by Snowflake after DESCRIBE INTEGRATION"
  value       = var.snowflake_external_id
}