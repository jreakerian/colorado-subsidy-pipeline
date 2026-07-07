# Service user for Airflow (data loading)
resource "snowflake_user" "airflow_service" {
  name              = "AIRFLOW_SERVICE"
  password          = var.airflow_service_password
  default_role      = snowflake_account_role.loader_role.name
  default_warehouse = var.loading_warehouse_name
  default_namespace = "${var.db_name}.${var.raw_schema_name}"
  must_change_password = false
  comment           = "Service account for Airflow data loading"
}

# Service user for dbt (data transformation)
resource "snowflake_user" "dbt_service" {
  name              = "DBT_SERVICE"
  password          = var.dbt_service_password
  default_role      = snowflake_account_role.transformer_role.name
  default_warehouse = var.transforming_warehouse_name
  default_namespace = "${var.db_name}.${var.silver_schema_name}"
  must_change_password = false
  comment           = "Service account for dbt transformations"
}

# Grant LOADER_ROLE to the Airflow service user
resource "snowflake_grant_account_role" "airflow_loader_grant" {
  role_name = snowflake_account_role.loader_role.name
  user_name = snowflake_user.airflow_service.name
}

# Grant TRANSFORMER_ROLE to the dbt service user
resource "snowflake_grant_account_role" "dbt_transformer_grant" {
  role_name = snowflake_account_role.transformer_role.name
  user_name = snowflake_user.dbt_service.name
}