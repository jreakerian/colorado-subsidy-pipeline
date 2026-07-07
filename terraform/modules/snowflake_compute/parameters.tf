# Session parameter for dbt transformation timeout
resource "snowflake_object_parameter" "transforming_timeout" {
  key         = "STATEMENT_TIMEOUT_IN_SECONDS"
  value       = "3600"  # 1 hour timeout for complex dbt models
  object_type = "WAREHOUSE"
  
  object_identifier {
    name = snowflake_warehouse.transforming_warehouse.name
  }
}

# Session parameter for dashboard query timeout
resource "snowflake_object_parameter" "analytics_timeout" {
  key         = "STATEMENT_TIMEOUT_IN_SECONDS"
  value       = "300"  # 5 minute timeout for dashboard queries
  object_type = "WAREHOUSE"

  object_identifier {
    name = snowflake_warehouse.analytics_warehouse.name
  }
}