output "snowflake_role_arn" {
  description = "ARN of the shared IAM role for all Snowflake integrations (storage, external volume, API)"
  value       = aws_iam_role.snowflake_role.arn
}

output "snowflake_role_name" {
  description = "Name of the shared IAM role for all Snowflake integrations"
  value       = aws_iam_role.snowflake_role.name
}


output "policy_arn" {
  description = "ARN of the IAM policy attached to the Snowflake integration role"
  value       = aws_iam_policy.lakehouse_rw_policy.arn
}


output "general_purpose_bucket_name" {
  description = "Name of the general-purpose project S3 bucket (raw uploads, scripts, misc)"
  value       = aws_s3_bucket.general_purpose.bucket
}

output "general_purpose_bucket_arn" {
  description = "ARN of the general-purpose project S3 bucket"
  value       = aws_s3_bucket.general_purpose.arn
}
