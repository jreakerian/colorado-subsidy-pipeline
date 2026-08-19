# ── AWS Infrastructure outputs ────────────────────────────────────────────────────────────
output "snowflake_integration_role_arn" {
  description = "ARN of the shared IAM role for all Snowflake integrations"
  value       = local.snowflake_role_arn
}

output "snowflake_integration_role_name" {
  description = "Name of the shared IAM role for all Snowflake integrations"
  value       = var.deploy_aws_infra ? module.aws_infra[0].snowflake_role_name : null
}

output "general_purpose_bucket_name" {
  description = "Name of the general-purpose project S3 bucket"
  value       = local.general_purpose_bucket_name
}

output "snowflake_external_id" {
  description = "The real Snowflake-generated AWS External ID (from DESCRIBE INTEGRATION)"
  value       = module.snowflake_foundation.external_id
  sensitive   = true
}

# ── Snowflake Foundation outputs ──────────────────────────────────────────────────
output "storage_integration_name" {
  description = "Name of the Snowflake storage integration"
  value       = module.snowflake_foundation.storage_integration_name
}

output "snowflake_iam_user_arn" {
  description = "Snowflake IAM user ARN (from DESCRIBE INTEGRATION)"
  value       = module.snowflake_foundation.iam_user_arn
}

output "external_volume_name" {
  description = "Snowflake external volume name for Iceberg tables"
  value       = module.snowflake_foundation.external_volume_name
}

output "database_name" {
  description = "Name of the Snowflake database deployed in this environment"
  value       = module.snowflake_foundation.database_name
}

output "raw_schema_name" {
  description = "Name of the RAW schema (e.g. RAW_DEV or RAW_PROD)"
  value       = module.snowflake_foundation.raw_schema_name
}

output "silver_schema_name" {
  description = "Name of the SILVER schema (e.g. SILVER_DEV or SILVER_PROD)"
  value       = module.snowflake_foundation.silver_schema_name
}

output "gold_schema_name" {
  description = "Name of the GOLD schema (e.g. GOLD_DEV or GOLD_PROD)"
  value       = module.snowflake_foundation.gold_schema_name
}

# ── Snowflake Compute outputs ─────────────────────────────────────────────────────
output "loading_warehouse_name" {
  value = module.snowflake_compute.loading_warehouse_name
}

output "transforming_warehouse_name" {
  value = module.snowflake_compute.transforming_warehouse_name
}

output "analytics_warehouse_name" {
  value = module.snowflake_compute.analytics_warehouse_name
}

output "daily_budget_monitor_name" {
  value = module.snowflake_compute.daily_budget_monitor_name
}

output "warehouse_specific_monitor_name" {
  value = module.snowflake_compute.warehouse_specific_monitor_name
}

# ── Snowflake Security outputs ────────────────────────────────────────────────────
output "loader_role_name" {
  value = module.snowflake_security.loader_role_name
}

output "transformer_role_name" {
  value = module.snowflake_security.transformer_role_name
}

output "analyst_role_name" {
  value = module.snowflake_security.analyst_role_name
}

output "airflow_service_user" {
  value = module.snowflake_security.airflow_service_user
}

output "dbt_service_user" {
  value = module.snowflake_security.dbt_service_user
}