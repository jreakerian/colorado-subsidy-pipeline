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

# Service user for dbt Semantic Layer (powers Tableau / Lightdash via MetricFlow)
resource "snowflake_user" "dbt_semantic_service" {
  name                 = "DBT_SEMANTIC_SERVICE"
  password             = var.dbt_semantic_service_password
  default_role         = snowflake_account_role.analyst_role.name
  default_warehouse    = var.analytics_warehouse_name
  default_namespace    = "${var.db_name}.${var.gold_schema_name}"
  must_change_password = false
  comment              = "Service account for dbt Semantic Layer queries"
}

# Service user for Metabase (Phase 3 operational dashboards)
resource "snowflake_user" "metabase_service" {
  name                 = "METABASE_SERVICE"
  password             = var.metabase_service_password
  default_role         = snowflake_account_role.analyst_role.name
  default_warehouse    = var.analytics_warehouse_name
  default_namespace    = "${var.db_name}.${var.gold_schema_name}"
  must_change_password = false
  comment              = "Service account for Metabase operational queries"
}

# Grant ANALYST_ROLE to BI service users
resource "snowflake_grant_account_role" "dbt_semantic_analyst_grant" {
  role_name = snowflake_account_role.analyst_role.name
  user_name = snowflake_user.dbt_semantic_service.name
}

resource "snowflake_grant_account_role" "metabase_analyst_grant" {
  role_name = snowflake_account_role.analyst_role.name
  user_name = snowflake_user.metabase_service.name
}