terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "colorado-subsidy-terraform-state"
    key          = "state/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.19"
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

locals {
  # Handles both ORG-ACCOUNT format ("FOFOXOE-EEB51968") and simple ACCOUNT format ("EEB51968")
  snowflake_org_name = length(split("-", var.snowflake_account)) > 1 ? split("-", var.snowflake_account)[0] : ""
  snowflake_acc_name = length(split("-", var.snowflake_account)) > 1 ? split("-", var.snowflake_account)[1] : var.snowflake_account
}

provider "snowflake" {
  organization_name = local.snowflake_org_name
  account_name      = local.snowflake_acc_name
  user              = var.snowflake_user
  role              = var.snowflake_role

  # Required to use the new type-specific file format resources and WIF (preview in v2.x)
  preview_features_enabled      = ["snowflake_object_parameter_resource", "snowflake_file_format_csv_resource", "snowflake_file_format_parquet_resource"]
  experimental_features_enabled = ["USER_ENABLE_DEFAULT_WORKLOAD_IDENTITY"]
}

data "aws_caller_identity" "current" {}

# ── AWS Infrastructure ────────────────────────────────────────────────────────────
# Creates the shared SnowflakeIntegrationRole, general-purpose S3 bucket,
# and S3 Tables bucket (Silver + Gold namespaces).
# Set deploy_aws_infra = false in prod.tfvars to skip this and reuse existing resources.
module "aws_infra" {
  source = "./modules/aws_infra"
  count  = var.deploy_aws_infra ? 1 : 0

  project_name                 = var.project_name
  environment                  = var.environment
  lakehouse_bucket_name        = var.lakehouse_bucket_name
  aws_region                   = var.aws_region
  snowflake_iam_user_arn       = var.snowflake_iam_user_arn
  snowflake_external_id        = var.snowflake_external_id
  snowflake_external_id_prefix = var.snowflake_external_id_prefix
}

# ── AWS resource references ───────────────────────────────────────────────────────
# When deploy_aws_infra = true  → pull values from the live module outputs.
# When deploy_aws_infra = false → pull values from the existing_* variables supplied
#                                  in prod.tfvars, pointing at the already-deployed
#                                  dev (shared) AWS resources.
locals {
  snowflake_role_arn          = var.deploy_aws_infra ? module.aws_infra[0].snowflake_role_arn : var.existing_snowflake_role_arn
  general_purpose_bucket_name = var.deploy_aws_infra ? module.aws_infra[0].general_purpose_bucket_name : var.existing_general_purpose_bucket
  snowflake_external_id_val   = var.deploy_aws_infra ? module.aws_infra[0].snowflake_external_id : var.existing_snowflake_external_id
}

# ── Snowflake Foundation ──────────────────────────────────────────────────────────
# One database per environment run (driven by var.db_name and var.environment).
module "snowflake_foundation" {
  source = "./modules/snowflake_foundation"

  environment            = var.environment
  db_name                = var.db_name
  role_arn               = local.snowflake_role_arn
  general_purpose_bucket = local.general_purpose_bucket_name
  snowflake_external_id  = local.snowflake_external_id_val
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
  shared_rsa_public_key       = var.shared_rsa_public_key

  # Foundation outputs — wire DB/schema names to create the dependency graph
  db_name                      = module.snowflake_foundation.database_name
  raw_schema_name              = module.snowflake_foundation.raw_schema_name
  silver_schema_name           = module.snowflake_foundation.silver_schema_name
  gold_schema_name             = module.snowflake_foundation.gold_schema_name
  csv_file_format_name         = module.snowflake_foundation.csv_file_format_name
  parquet_file_format_name     = module.snowflake_foundation.parquet_file_format_name
  stage_dependency_placeholder = module.snowflake_foundation.raw_csv_stage_name
}
