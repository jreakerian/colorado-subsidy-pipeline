output "loading_warehouse_name" {
  description = "Name of the loading warehouse"
  value       = snowflake_warehouse.loading_warehouse.name
}

output "transforming_warehouse_name" {
  description = "Name of the transforming warehouse"
  value       = snowflake_warehouse.transforming_warehouse.name
}

output "analytics_warehouse_name" {
  description = "Name of the analytics warehouse"
  value       = snowflake_warehouse.analytics_warehouse.name
}

output "daily_budget_monitor_name" {
  description = "Name of the daily budget resource monitor"
  value       = snowflake_resource_monitor.daily_budget.name
}

output "warehouse_specific_monitor_name" {
  description = "Name of the warehouse-specific resource monitor"
  value       = snowflake_resource_monitor.warehouse_specific.name
}