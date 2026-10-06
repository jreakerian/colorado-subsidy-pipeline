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
# IMPORTANT: depends_on includes BOTH the schema-level grant (ordering) AND the
# stage placeholder (ensures the stage object exists before Snowflake is asked to
# grant on it). Without this, Terraform may create grants in parallel with stage
# creation, producing an 'object does not exist' race condition.
resource "snowflake_grant_privileges_to_account_role" "loader_raw_csv" {
  account_role_name = snowflake_account_role.loader_role.name
  privileges        = ["USAGE"]
  on_schema_object {
    object_type = "STAGE"
    object_name = "\"${var.db_name}\".\"${var.raw_schema_name}\".\"RAW_CSV_STAGE\""
  }
  depends_on = [
    snowflake_grant_privileges_to_account_role.loader_raw,
    # Stage existence guard — wired from snowflake_foundation.raw_csv_stage_name
    # so Terraform knows the stage must be created before this grant runs.
    terraform_data.stage_exists_guard,
  ]
}

resource "snowflake_grant_privileges_to_account_role" "transformer_raw_csv" {
  account_role_name = snowflake_account_role.transformer_role.name
  privileges        = ["USAGE"]
  on_schema_object {
    object_type = "STAGE"
    object_name = "\"${var.db_name}\".\"${var.raw_schema_name}\".\"RAW_CSV_STAGE\""
  }
  depends_on = [
    snowflake_grant_privileges_to_account_role.transformer_raw,
    terraform_data.stage_exists_guard,
  ]
}

# Sentinel resource: wraps var.stage_dependency_placeholder so cross-module
# depends_on can reference it as a concrete resource node in the DAG.
resource "terraform_data" "stage_exists_guard" {
  input = var.stage_dependency_placeholder
}

# ── TABLE OWNERSHIP GRANTS ───────────────────────────────────────────────────────
# dbt uses CREATE OR REPLACE TABLE/VIEW, which requires OWNERSHIP on the object.
# Granting OWNERSHIP at the schema level (all + future) ensures TRANSFORMER_ROLE
# can recreate any model without manual per-table grants as the project grows.
#
# COPY CURRENT GRANTS preserves downstream SELECT grants (e.g. ANALYST_ROLE)
# when ownership changes hands.

resource "snowflake_grant_ownership" "transformer_owns_silver_tables" {
  account_role_name = snowflake_account_role.transformer_role.name
  on {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${var.db_name}\".\"${var.silver_schema_name}\""
    }
  }
  outbound_privileges = "COPY"
  depends_on          = [snowflake_grant_privileges_to_account_role.transformer_silver]
}

resource "snowflake_grant_ownership" "transformer_owns_silver_views" {
  account_role_name = snowflake_account_role.transformer_role.name
  on {
    all {
      object_type_plural = "VIEWS"
      in_schema          = "\"${var.db_name}\".\"${var.silver_schema_name}\""
    }
  }
  outbound_privileges = "COPY"
  depends_on          = [snowflake_grant_privileges_to_account_role.transformer_silver]
}

resource "snowflake_grant_ownership" "transformer_owns_gold_tables" {
  account_role_name = snowflake_account_role.transformer_role.name
  on {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${var.db_name}\".\"${var.gold_schema_name}\""
    }
  }
  outbound_privileges = "COPY"
  depends_on          = [snowflake_grant_privileges_to_account_role.transformer_gold]
}

resource "snowflake_grant_ownership" "transformer_owns_gold_views" {
  account_role_name = snowflake_account_role.transformer_role.name
  on {
    all {
      object_type_plural = "VIEWS"
      in_schema          = "\"${var.db_name}\".\"${var.gold_schema_name}\""
    }
  }
  outbound_privileges = "COPY"
  depends_on          = [snowflake_grant_privileges_to_account_role.transformer_gold]
}

# ── RAW SCHEMA OWNERSHIP GRANTS ──────────────────────────────────────────────────
# dbt staging models are materialised as VIEWS in the RAW schema
# (dbt_project.yml: staging +schema: raw).
# If a previous pipeline run created these views under LOADER_ROLE, TRANSFORMER_ROLE
# cannot issue CREATE OR REPLACE VIEW on them without OWNERSHIP.
# Granting OWNERSHIP here ensures dbt can always rebuild staging views regardless
# of which role originally created them.

resource "snowflake_grant_ownership" "transformer_owns_raw_tables" {
  account_role_name = snowflake_account_role.transformer_role.name
  on {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${var.db_name}\".\"${var.raw_schema_name}\""
    }
  }
  outbound_privileges = "COPY"
  depends_on          = [snowflake_grant_privileges_to_account_role.transformer_raw]
}

resource "snowflake_grant_ownership" "transformer_owns_raw_views" {
  account_role_name = snowflake_account_role.transformer_role.name
  on {
    all {
      object_type_plural = "VIEWS"
      in_schema          = "\"${var.db_name}\".\"${var.raw_schema_name}\""
    }
  }
  outbound_privileges = "COPY"
  depends_on          = [snowflake_grant_privileges_to_account_role.transformer_raw]
}
