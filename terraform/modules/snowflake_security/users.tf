# ── Service users for data pipeline tools ─────────────────────────────────────────
# snowflake_legacy_service_user corresponds to TYPE = LEGACY_SERVICE, which
# retains password authentication support.  must_change_password is not a
# valid attribute on this resource type and has been removed.

# Service user for Airflow (data loading)
resource "snowflake_legacy_service_user" "airflow_service" {
  name              = "AIRFLOW_SERVICE"
  password          = var.airflow_service_password
  default_role      = snowflake_account_role.loader_role.name
  default_warehouse = var.loading_warehouse_name
  default_namespace = "${var.db_name}.${var.raw_schema_name}"
  comment           = "Service account for Airflow data loading"

  lifecycle {
    ignore_changes = [password]
  }
}

# Service user for dbt (data transformation)
resource "snowflake_legacy_service_user" "dbt_service" {
  name              = "DBT_SERVICE"
  password          = var.dbt_service_password
  default_role      = snowflake_account_role.transformer_role.name
  default_warehouse = var.transforming_warehouse_name
  default_namespace = "${var.db_name}.${var.silver_schema_name}"
  comment           = "Service account for dbt transformations"

  lifecycle {
    ignore_changes = [password]
  }
}

# Grant LOADER_ROLE to the Airflow service user
resource "snowflake_grant_account_role" "airflow_loader_grant" {
  role_name = snowflake_account_role.loader_role.name
  user_name = snowflake_legacy_service_user.airflow_service.name
}

# Grant TRANSFORMER_ROLE to the dbt service user
resource "snowflake_grant_account_role" "dbt_transformer_grant" {
  role_name = snowflake_account_role.transformer_role.name
  user_name = snowflake_legacy_service_user.dbt_service.name
}

# Service user for dbt Semantic Layer (powers Tableau / Lightdash via MetricFlow)
resource "snowflake_legacy_service_user" "dbt_semantic_service" {
  name              = "DBT_SEMANTIC_SERVICE"
  password          = var.dbt_semantic_service_password
  default_role      = snowflake_account_role.analyst_role.name
  default_warehouse = var.analytics_warehouse_name
  default_namespace = "${var.db_name}.${var.gold_schema_name}"
  comment           = "Service account for dbt Semantic Layer queries"

  lifecycle {
    ignore_changes = [password]
  }
}

# Service user for Metabase (Phase 3 operational dashboards)
resource "snowflake_legacy_service_user" "metabase_service" {
  name              = "METABASE_SERVICE"
  password          = var.metabase_service_password
  default_role      = snowflake_account_role.analyst_role.name
  default_warehouse = var.analytics_warehouse_name
  default_namespace = "${var.db_name}.${var.gold_schema_name}"
  comment           = "Service account for Metabase operational queries"

  lifecycle {
    ignore_changes = [password]
  }
}

# CI-only dbt service account — GitHub Actions OIDC, dev environment
resource "snowflake_service_user" "dbt_ci_svc" {
  name              = "DBT_CI_SVC"
  comment           = "CI-only dbt service account, PR validation builds, WIF auth via GitHub Actions OIDC"
  default_warehouse = var.transforming_warehouse_name
  default_role      = snowflake_account_role.cicd_role.name

  default_workload_identity {
    oidc {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:jreakerian/colorado-subsidy-pipeline:environment:dev"
    }
  }
}

# CD-only dbt service account — GitHub Actions OIDC, prod environment
resource "snowflake_service_user" "dbt_cd_svc" {
  name              = "DBT_CD_SVC"
  comment           = "CD-only dbt service account, prod builds and docs generation, WIF auth via GitHub Actions OIDC"
  default_warehouse = var.transforming_warehouse_name
  default_role      = snowflake_account_role.cicd_role.name

  default_workload_identity {
    oidc {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:jreakerian/colorado-subsidy-pipeline:environment:prod"
    }
  }
}

# Grant CICD_ROLE to the dbt CI service user
resource "snowflake_grant_account_role" "grant_cicd_to_dbt_ci" {
  role_name = snowflake_account_role.cicd_role.name
  user_name = snowflake_service_user.dbt_ci_svc.name
}

# Grant CICD_ROLE to the dbt CD service user
resource "snowflake_grant_account_role" "grant_cicd_to_dbt_cd" {
  role_name = snowflake_account_role.cicd_role.name
  user_name = snowflake_service_user.dbt_cd_svc.name
}

# Terraform CI service account — GitHub Actions OIDC, pull_request events
# Read-only planning identity. Never used for apply.
resource "snowflake_service_user" "tf_ci_svc" {
  name              = "TF_CI_SVC"
  comment           = "Terraform CI planner — WIF auth via GitHub Actions OIDC on pull_request events. Read-only; never used for apply."
  default_warehouse = var.transforming_warehouse_name
  default_role      = snowflake_account_role.cicd_role.name

  default_workload_identity {
    oidc {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:jreakerian/colorado-subsidy-pipeline:pull_request"
    }
  }
}

# Grant CICD_ROLE to TF_CI_SVC

resource "snowflake_grant_account_role" "grant_cicd_to_tf_ci" {
  role_name = snowflake_account_role.cicd_role.name
  user_name = snowflake_service_user.tf_ci_svc.name
}

# Terraform CD service account — GitHub Actions OIDC, push to main events
# Has ACCOUNTADMIN so it can create/modify/delete all Snowflake infrastructure.

resource "snowflake_service_user" "tf_cd_svc" {
  name              = "TF_CD_SVC"
  comment           = "Terraform CD applier — WIF auth via GitHub Actions OIDC on push to main. Requires ACCOUNTADMIN to manage Snowflake infrastructure."
  default_warehouse = var.transforming_warehouse_name
  default_role      = snowflake_account_role.cicd_role.name

  default_workload_identity {
    oidc {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:jreakerian/colorado-subsidy-pipeline:ref:refs/heads/main"
    }
  }
}

# Grant ACCOUNTADMIN to TF_CD_SVC — required for terraform apply to provision
# databases, warehouses, roles, users, and all other Snowflake resources
resource "snowflake_grant_account_role" "grant_accountadmin_to_tf_cd" {
  role_name = "ACCOUNTADMIN"
  user_name = snowflake_service_user.tf_cd_svc.name
}


# Grant ANALYST_ROLE to BI service users
resource "snowflake_grant_account_role" "dbt_semantic_analyst_grant" {
  role_name = snowflake_account_role.analyst_role.name
  user_name = snowflake_legacy_service_user.dbt_semantic_service.name
}

resource "snowflake_grant_account_role" "metabase_analyst_grant" {
  role_name = snowflake_account_role.analyst_role.name
  user_name = snowflake_legacy_service_user.metabase_service.name
}
