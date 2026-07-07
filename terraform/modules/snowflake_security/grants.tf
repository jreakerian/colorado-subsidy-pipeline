# ── Warehouse grants ──────────────────────────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "loader_warehouse" {
  account_role_name = snowflake_account_role.loader_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.loading_warehouse_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_warehouse" {
  account_role_name = snowflake_account_role.transformer_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.transforming_warehouse_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_warehouse" {
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.analytics_warehouse_name
  }
}

# ── Stage grants (RAW schema hosts the CSV stage) ─────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "loader_raw_csv" {
  account_role_name = snowflake_account_role.loader_role.name
  privileges        = ["USAGE"]
  on_schema_object {
    object_type = "STAGE"
    object_name = "\"${var.db_name}\".\"${var.raw_schema_name}\".\"RAW_CSV_STAGE\""
  }
  depends_on = [snowflake_grant_privileges_to_account_role.loader_raw]
}

resource "snowflake_grant_privileges_to_account_role" "transformer_raw_csv" {
  account_role_name = snowflake_account_role.transformer_role.name
  privileges        = ["USAGE"]
  on_schema_object {
    object_type = "STAGE"
    object_name = "\"${var.db_name}\".\"${var.raw_schema_name}\".\"RAW_CSV_STAGE\""
  }
  depends_on = [snowflake_grant_privileges_to_account_role.transformer_raw]
}