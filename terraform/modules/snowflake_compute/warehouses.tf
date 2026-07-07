# Warehouse for data loading operations
resource "snowflake_warehouse" "loading_warehouse" {
  name                = "LOADING_WH"
  warehouse_size      = var.loading_warehouse_size
  warehouse_type      = "STANDARD"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  min_cluster_count   = 1
  max_cluster_count   = 1
  scaling_policy      = "STANDARD"
  comment             = "Warehouse for data loading operations"
  resource_monitor    = snowflake_resource_monitor.daily_budget.name
}

# Warehouse for data transformation (dbt)
resource "snowflake_warehouse" "transforming_warehouse" {
  name                = "TRANSFORMING_WH"
  warehouse_size      = var.transforming_warehouse_size
  warehouse_type      = "STANDARD"
  auto_suspend        = 300
  auto_resume         = true
  initially_suspended = true
  min_cluster_count   = 1
  max_cluster_count   = 2
  scaling_policy      = "STANDARD"
  comment             = "Warehouse for dbt transformations"
  resource_monitor    = snowflake_resource_monitor.warehouse_specific.name
}

# Warehouse for analytics/BI queries
resource "snowflake_warehouse" "analytics_warehouse" {
  name                                = "ANALYTICS_WH"
  warehouse_size                      = var.analytics_warehouse_size
  warehouse_type                      = "STANDARD"
  auto_suspend                        = 600
  auto_resume                         = true
  initially_suspended                 = true
  min_cluster_count                   = 1
  max_cluster_count                   = 3
  scaling_policy                      = "ECONOMY"
  comment                             = "Warehouse for analytics and BI queries"
  resource_monitor                    = snowflake_resource_monitor.daily_budget.name
  enable_query_acceleration           = true
  query_acceleration_max_scale_factor = 4
}