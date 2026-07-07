output "storage_integration_name" {
  description = "Name of the Snowflake storage integration"
  value       = snowflake_storage_integration.s3_integration.name
}

output "external_id" {
  description = "External ID for Snowflake S3 integration"
  value       = snowflake_storage_integration.s3_integration.storage_aws_external_id
  sensitive   = true
}

output "iam_user_arn" {
  description = "Snowflake IAM user ARN from the storage integration"
  value       = snowflake_storage_integration.s3_integration.storage_aws_iam_user_arn
}

# ── Database outputs ──────────────────────────────────────────────────────────────
output "database_name" {
  description = "Name of the Snowflake database for this environment"
  value       = snowflake_database.colorado_crime_db.name
}

output "raw_schema_name" {
  description = "Name of the RAW schema (e.g. RAW_DEV or RAW_PROD)"
  value       = snowflake_schema.raw.name
}

output "silver_schema_name" {
  description = "Name of the SILVER schema (e.g. SILVER_DEV or SILVER_PROD)"
  value       = snowflake_schema.silver.name
}

output "gold_schema_name" {
  description = "Name of the GOLD schema (e.g. GOLD_DEV or GOLD_PROD)"
  value       = snowflake_schema.gold.name
}

# ── Shared ───────────────────────────────────────────────────────────────────────
output "external_volume_name" {
  description = "Snowflake external volume name for Iceberg tables"
  value       = snowflake_external_volume.iceberg_volume.name
}

# Aliases consumed by other modules
output "staging_schema_name" {
  description = "Alias → RAW schema (used by snowflake_api module)"
  value       = snowflake_schema.raw.name
}

output "raw_csv_stage_name" {
  description = "Name of the raw CSV stage"
  value       = snowflake_stage.raw_csv_stage.name
}

output "csv_file_format_name" {
  value = snowflake_file_format.csv_format.name
}

output "parquet_file_format_name" {
  value = snowflake_file_format.parquet_format.name
}