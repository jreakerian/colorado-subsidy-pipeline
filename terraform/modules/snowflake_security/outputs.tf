output "loader_role_name" {
  description = "Name of the loader role"
  value       = snowflake_account_role.loader_role.name
}

output "transformer_role_name" {
  description = "Name of the transformer role"
  value       = snowflake_account_role.transformer_role.name
}

output "analyst_role_name" {
  description = "Name of the analyst role"
  value       = snowflake_account_role.analyst_role.name
}

output "airflow_service_user" {
  description = "Name of the Airflow service user"
  value       = snowflake_legacy_service_user.airflow_service.name
}

output "dbt_service_user" {
  description = "Name of the dbt service user"
  value       = snowflake_legacy_service_user.dbt_service.name
}