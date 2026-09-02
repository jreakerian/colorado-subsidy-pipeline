# Daily budget resource monitor (shared)
resource "snowflake_resource_monitor" "daily_budget" {
  name            = "DAILY_BUDGET_MONITOR"
  credit_quota    = 100
  frequency       = "DAILY"
  start_timestamp = "IMMEDIATELY"
  notify_users    = []
  notify_triggers = [75, 90]
  suspend_trigger = 100
}

# Warehouse-specific resource monitor
resource "snowflake_resource_monitor" "warehouse_specific" {
  name            = "WAREHOUSE_SPECIFIC_MONITOR"
  credit_quota    = 50
  frequency       = "DAILY"
  start_timestamp = "IMMEDIATELY"
  notify_users    = []
  notify_triggers = [80]
  suspend_trigger = 100
}
