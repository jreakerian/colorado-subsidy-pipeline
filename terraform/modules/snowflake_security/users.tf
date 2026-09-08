# ── Service users for data pipeline tools ─────────────────────────────────────────

# Service user for Airflow (data loading)
resource "snowflake_service_user" "airflow_service" {
  name              = "AIRFLOW_SERVICE"
  rsa_public_key    = var.shared_rsa_public_key
  default_role      = snowflake_account_role.loader_role.name
  default_warehouse = var.loading_warehouse_name
  default_namespace = "${var.db_name}.${var.raw_schema_name}"
  comment           = "Service account for Airflow data loading"
}

# Service user for dbt (data transformation)
resource "snowflake_service_user" "dbt_service" {
  name              = "DBT_SERVICE"
  rsa_public_key    = var.shared_rsa_public_key
  default_role      = snowflake_account_role.transformer_role.name
  default_warehouse = var.transforming_warehouse_name
  default_namespace = "${var.db_name}.${var.silver_schema_name}"
  comment           = "Service account for dbt transformations"
}

# Grant LOADER_ROLE to the Airflow service user
resource "snowflake_grant_account_role" "airflow_loader_grant" {
  role_name = snowflake_account_role.loader_role.name
  user_name = snowflake_service_user.airflow_service.name
}

# Grant TRANSFORMER_ROLE to the dbt service user
resource "snowflake_grant_account_role" "dbt_transformer_grant" {
  role_name = snowflake_account_role.transformer_role.name
  user_name = snowflake_service_user.dbt_service.name
}

# Service user for dbt Semantic Layer (powers Tableau / Lightdash via MetricFlow)
resource "snowflake_service_user" "dbt_semantic_service" {
  name              = "DBT_SEMANTIC_SERVICE"
  rsa_public_key    = var.shared_rsa_public_key
  default_role      = snowflake_account_role.analyst_role.name
  default_warehouse = var.analytics_warehouse_name
  default_namespace = "${var.db_name}.${var.gold_schema_name}"
  comment           = "Service account for dbt Semantic Layer queries"
}

# Service user for Metabase (Phase 3 operational dashboards)
resource "snowflake_service_user" "metabase_service" {
  name              = "METABASE_SERVICE"
  rsa_public_key    = var.shared_rsa_public_key
  default_role      = snowflake_account_role.analyst_role.name
  default_warehouse = var.analytics_warehouse_name
  default_namespace = "${var.db_name}.${var.gold_schema_name}"
  comment           = "Service account for Metabase operational queries"
}

# CI service account — GitHub Actions OIDC, pull_request events
# Read-only planning identity used by both Terraform and dbt. Never used for apply.
resource "snowflake_service_user" "ci_svc" {
  name              = "CI_SVC"
  comment           = "CI planner — WIF auth via GitHub Actions OIDC on pull_request events. Read-only; never used for apply."
  default_warehouse = var.transforming_warehouse_name
  default_role      = snowflake_account_role.cicd_role.name

  default_workload_identity {
    oidc {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:jreakerian/colorado-subsidy-pipeline:pull_request"
    }
  }
}

# Grant CICD_ROLE to CI_SVC
resource "snowflake_grant_account_role" "grant_cicd_to_ci" {
  role_name = snowflake_account_role.cicd_role.name
  user_name = snowflake_service_user.ci_svc.name
}

# Grant ACCOUNTADMIN to CI_SVC so it can read all objects during terraform plan.
# Storage integrations, external volumes, and object parameters are ACCOUNTADMIN-owned
# and invisible to lower roles, causing phantom destroys in the plan output.
resource "snowflake_grant_account_role" "grant_accountadmin_to_ci" {
  role_name = "ACCOUNTADMIN"
  user_name = snowflake_service_user.ci_svc.name
}

# CD service account — GitHub Actions OIDC, push to main events
# Used by Terraform (plan) and dbt (deploy).
# Has ACCOUNTADMIN so it can read/modify infrastructure.

resource "snowflake_service_user" "cd_svc" {
  name              = "CD_SVC"
  comment           = "CD service — WIF auth via GitHub Actions OIDC on push to main. Used by Terraform plan and dbt deploy."
  default_warehouse = var.transforming_warehouse_name
  default_role      = snowflake_account_role.cicd_role.name

  default_workload_identity {
    oidc {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:jreakerian/colorado-subsidy-pipeline:ref:refs/heads/main"
    }
  }
}

# Grant ACCOUNTADMIN to CD_SVC
resource "snowflake_grant_account_role" "grant_accountadmin_to_cd" {
  role_name = "ACCOUNTADMIN"
  user_name = snowflake_service_user.cd_svc.name
}

# Terraform CD apply service account — GitHub Actions OIDC, environment:prod jobs
# When a GitHub Actions job has 'environment: prod' set, the OIDC sub claim
# changes from 'ref:refs/heads/main' to 'environment:prod'. A dedicated user
# is required to match that sub claim for the apply job.
resource "snowflake_service_user" "tf_cd_apply_svc" {
  name              = "TF_CD_APPLY_SVC"
  comment           = "Terraform CD apply identity — WIF auth via GitHub Actions OIDC on environment:prod jobs. Requires ACCOUNTADMIN to apply Snowflake infrastructure."
  default_warehouse = var.transforming_warehouse_name
  default_role      = snowflake_account_role.cicd_role.name

  default_workload_identity {
    oidc {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:jreakerian/colorado-subsidy-pipeline:environment:prod"
    }
  }
}

resource "snowflake_grant_account_role" "grant_accountadmin_to_tf_cd_apply" {
  role_name = "ACCOUNTADMIN"
  user_name = snowflake_service_user.tf_cd_apply_svc.name
}

resource "snowflake_grant_account_role" "grant_cicd_to_tf_cd_apply" {
  role_name = snowflake_account_role.cicd_role.name
  user_name = snowflake_service_user.tf_cd_apply_svc.name
}


# Grant ANALYST_ROLE to BI service users
resource "snowflake_grant_account_role" "dbt_semantic_analyst_grant" {
  role_name = snowflake_account_role.analyst_role.name
  user_name = snowflake_service_user.dbt_semantic_service.name
}

resource "snowflake_grant_account_role" "metabase_analyst_grant" {
  role_name = snowflake_account_role.analyst_role.name
  user_name = snowflake_service_user.metabase_service.name
}

# ── CICD_ROLE user visibility grants ──────────────────────────────────────────────
# CICD_ROLE is the active role for TF_CI_SVC during terraform plan.
# Without MONITOR on each user, the Snowflake provider returns a 003001 access
# control error when reading user state, causing the plan to fail.
resource "snowflake_grant_privileges_to_account_role" "cicd_monitor_airflow" {
  account_role_name = snowflake_account_role.cicd_role.name
  privileges        = ["MONITOR"]
  on_account_object {
    object_type = "USER"
    object_name = snowflake_service_user.airflow_service.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "cicd_monitor_dbt_service" {
  account_role_name = snowflake_account_role.cicd_role.name
  privileges        = ["MONITOR"]
  on_account_object {
    object_type = "USER"
    object_name = snowflake_service_user.dbt_service.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "cicd_monitor_dbt_semantic" {
  account_role_name = snowflake_account_role.cicd_role.name
  privileges        = ["MONITOR"]
  on_account_object {
    object_type = "USER"
    object_name = snowflake_service_user.dbt_semantic_service.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "cicd_monitor_metabase" {
  account_role_name = snowflake_account_role.cicd_role.name
  privileges        = ["MONITOR"]
  on_account_object {
    object_type = "USER"
    object_name = snowflake_service_user.metabase_service.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "cicd_monitor_ci_svc" {
  account_role_name = snowflake_account_role.cicd_role.name
  privileges        = ["MONITOR"]
  on_account_object {
    object_type = "USER"
    object_name = snowflake_service_user.ci_svc.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "cicd_monitor_cd_svc" {
  account_role_name = snowflake_account_role.cicd_role.name
  privileges        = ["MONITOR"]
  on_account_object {
    object_type = "USER"
    object_name = snowflake_service_user.cd_svc.name
  }
}
