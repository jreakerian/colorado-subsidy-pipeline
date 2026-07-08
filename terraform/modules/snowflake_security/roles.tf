# Functional roles for the Colorado Subsidy data pipeline
resource "snowflake_account_role" "loader_role" {
  name    = "LOADER_ROLE"
  comment = "Role for data loading operations (Airflow)"
}

resource "snowflake_account_role" "transformer_role" {
  name    = "TRANSFORMER_ROLE"
  comment = "Role for data transformation operations (dbt)"
}

resource "snowflake_account_role" "analyst_role" {
  name    = "ANALYST_ROLE"
  comment = "Role for data analysis and reporting"
}

# Role hierarchy: TRANSFORMER inherits LOADER, ANALYST inherits TRANSFORMER
resource "snowflake_grant_account_role" "transformer_inherits_loader" {
  role_name        = snowflake_account_role.loader_role.name
  parent_role_name = snowflake_account_role.transformer_role.name
}

resource "snowflake_grant_account_role" "analyst_inherits_transformer" {
  role_name        = snowflake_account_role.transformer_role.name
  parent_role_name = snowflake_account_role.analyst_role.name
}

# ── DATABASE GRANTS ───────────────────────────────────────────────────────────────
# By referencing var.db_name (which comes from module.snowflake_foundation.database_name),
# Terraform knows to revoke these grants BEFORE the database is destroyed.

resource "snowflake_grant_privileges_to_account_role" "loader_db" {
  account_role_name = snowflake_account_role.loader_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = var.db_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_db" {
  account_role_name = snowflake_account_role.transformer_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = var.db_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_db" {
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = var.db_name
  }
}

# ── SCHEMA GRANTS — RAW ───────────────────────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "loader_raw" {
  account_role_name = snowflake_account_role.loader_role.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${var.db_name}\".\"${var.raw_schema_name}\""
  }
  depends_on = [snowflake_grant_privileges_to_account_role.loader_db]
}

resource "snowflake_grant_privileges_to_account_role" "transformer_raw" {
  account_role_name = snowflake_account_role.transformer_role.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${var.db_name}\".\"${var.raw_schema_name}\""
  }
  depends_on = [snowflake_grant_privileges_to_account_role.transformer_db]
}

resource "snowflake_grant_privileges_to_account_role" "analyst_raw" {
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${var.db_name}\".\"${var.raw_schema_name}\""
  }
  depends_on = [snowflake_grant_privileges_to_account_role.analyst_db]
}

# ── SCHEMA GRANTS — SILVER ────────────────────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "transformer_silver" {
  account_role_name = snowflake_account_role.transformer_role.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${var.db_name}\".\"${var.silver_schema_name}\""
  }
  depends_on = [snowflake_grant_privileges_to_account_role.transformer_db]
}

resource "snowflake_grant_privileges_to_account_role" "analyst_silver" {
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${var.db_name}\".\"${var.silver_schema_name}\""
  }
  depends_on = [snowflake_grant_privileges_to_account_role.analyst_db]
}

# ── SCHEMA GRANTS — GOLD ──────────────────────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "analyst_gold" {
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${var.db_name}\".\"${var.gold_schema_name}\""
  }
  depends_on = [snowflake_grant_privileges_to_account_role.analyst_db]
}

# ── FUTURE TABLE GRANTS ───────────────────────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "loader_future_tables_raw" {
  account_role_name = snowflake_account_role.loader_role.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${var.db_name}\".\"${var.raw_schema_name}\""
    }
  }
  depends_on = [snowflake_grant_privileges_to_account_role.loader_raw]
}

resource "snowflake_grant_privileges_to_account_role" "transformer_future_tables_silver" {
  account_role_name = snowflake_account_role.transformer_role.name
  privileges        = ["ALL"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${var.db_name}\".\"${var.silver_schema_name}\""
    }
  }
  depends_on = [snowflake_grant_privileges_to_account_role.transformer_silver]
}

resource "snowflake_grant_privileges_to_account_role" "analyst_future_tables_gold" {
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${var.db_name}\".\"${var.gold_schema_name}\""
    }
  }
  depends_on = [snowflake_grant_privileges_to_account_role.analyst_gold]
}

# ── FILE FORMAT GRANTS ────────────────────────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "loader_csv" {
  account_role_name = snowflake_account_role.loader_role.name
  privileges        = ["USAGE"]
  on_schema_object {
    object_type = "FILE FORMAT"
    object_name = "\"${var.db_name}\".\"${var.raw_schema_name}\".\"${var.csv_file_format_name}\""
  }
  depends_on = [
    snowflake_grant_privileges_to_account_role.loader_raw,
    # File format must exist before Snowflake accepts the grant
    terraform_data.csv_format_guard,
  ]
}

resource "snowflake_grant_privileges_to_account_role" "transformer_csv" {
  account_role_name = snowflake_account_role.transformer_role.name
  privileges        = ["USAGE"]
  on_schema_object {
    object_type = "FILE FORMAT"
    object_name = "\"${var.db_name}\".\"${var.raw_schema_name}\".\"${var.csv_file_format_name}\""
  }
  depends_on = [
    snowflake_grant_privileges_to_account_role.transformer_raw,
    terraform_data.csv_format_guard,
  ]
}

resource "snowflake_grant_privileges_to_account_role" "transformer_parquet" {
  account_role_name = snowflake_account_role.transformer_role.name
  privileges        = ["USAGE"]
  on_schema_object {
    object_type = "FILE FORMAT"
    object_name = "\"${var.db_name}\".\"${var.raw_schema_name}\".\"${var.parquet_file_format_name}\""
  }
  depends_on = [
    snowflake_grant_privileges_to_account_role.transformer_raw,
    terraform_data.parquet_format_guard,
  ]
}

# Sentinel resources: wrap file format name vars so cross-module depends_on can
# reference them as concrete DAG nodes. Prevents grants from running before the
# file format objects are fully created in Snowflake.
resource "terraform_data" "csv_format_guard" {
  input = var.csv_file_format_name
}

resource "terraform_data" "parquet_format_guard" {
  input = var.parquet_file_format_name
}