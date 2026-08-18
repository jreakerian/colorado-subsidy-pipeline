terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.87"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner_team
      ManagedBy   = "Terraform"
      DataTier    = "Lakehouse"
    }
  }
}

provider "snowflake" {
  organization_name      = var.snowflake_organization_name
  account_name           = var.snowflake_account_name
  user                   = var.snowflake_user
  authenticator          = "SNOWFLAKE_JWT"
  private_key            = file(var.snowflake_private_key_path)
  private_key_passphrase = var.private_key_passphrase
  role                   = var.snowflake_role
}

data "aws_caller_identity" "current" {}

# ── AWS Infrastructure ────────────────────────────────────────────────────────────
# Creates the shared SnowflakeIntegrationRole, general-purpose S3 bucket,
# and S3 Tables bucket (Silver + Gold namespaces).
module "aws_infra" {
  source = "./modules/aws_infra"

  project_name              = var.project_name
  environment               = var.environment
  lakehouse_bucket_name     = var.lakehouse_bucket_name
  aws_region                = var.aws_region
  snowflake_iam_user_arn    = var.snowflake_iam_user_arn
  snowflake_external_id     = var.snowflake_external_id
  snowflake_external_id_prefix = var.snowflake_external_id_prefix
}

# ── Snowflake Foundation ──────────────────────────────────────────────────────────
# One database per environment run (driven by var.db_name and var.environment).
# Schemas: RAW_DEV/RAW_PROD, SILVER_DEV/SILVER_PROD, GOLD_DEV/GOLD_PROD
module "snowflake_foundation" {
  source = "./modules/snowflake_foundation"

  environment            = var.environment
  db_name                = var.db_name
  role_arn               = module.aws_infra.snowflake_role_arn
  general_purpose_bucket = module.aws_infra.general_purpose_bucket_name
  snowflake_external_id  = module.aws_infra.snowflake_external_id
}

# ── Snowflake Compute ─────────────────────────────────────────────────────────────
# Warehouses, resource monitors, parameters.
module "snowflake_compute" {
  source = "./modules/snowflake_compute"

  environment                 = var.environment
  loading_warehouse_size      = var.loading_warehouse_size
  transforming_warehouse_size = var.transforming_warehouse_size
  analytics_warehouse_size    = var.analytics_warehouse_size
}

# ── Snowflake Security ────────────────────────────────────────────────────────────
# Roles, users, grants — all scoped to the current environment's database.
module "snowflake_security" {
  source = "./modules/snowflake_security"

  loading_warehouse_name      = module.snowflake_compute.loading_warehouse_name
  transforming_warehouse_name = module.snowflake_compute.transforming_warehouse_name
  analytics_warehouse_name    = module.snowflake_compute.analytics_warehouse_name
  airflow_service_password    = var.airflow_service_password
  dbt_service_password        = var.dbt_service_password

  # Foundation outputs — wire DB/schema names to create the dependency graph
  db_name                  = module.snowflake_foundation.database_name
  raw_schema_name          = module.snowflake_foundation.raw_schema_name
  silver_schema_name       = module.snowflake_foundation.silver_schema_name
  gold_schema_name         = module.snowflake_foundation.gold_schema_name
  csv_file_format_name     = module.snowflake_foundation.csv_file_format_name
  parquet_file_format_name = module.snowflake_foundation.parquet_file_format_name
  stage_dependency_placeholder = module.snowflake_foundation.raw_csv_stage_name
}