# ── Environment ───────────────────────────────────────────────────────────────────
environment  = "prod"
project_name = "colorado-subsidy-pipeline"

# ── Snowflake Database ────────────────────────────────────────────────────────────
# This is the ONLY database created when applying with this file.
# Full name will be COLORADO_CRIME_DB_PROD
db_name = "COLORADO_CRIME_DB"

# ── AWS Module Toggle ─────────────────────────────────────────────────────────────
deploy_aws_infra = true

# ── Existing AWS Resources (used when deploy_aws_infra = false) ───────────────────
# Copy these values from the dev terraform output or the AWS console.
aws_region                      = "us-east-2"
lakehouse_bucket_name           = "co-subsidy-lakehouse-dev" # shared dev bucket
existing_snowflake_role_arn     = "arn:aws:iam::875388088287:role/SnowflakeIntegrationRole-colorado-subsidy-pipeline-dev"
existing_general_purpose_bucket = "colorado-subsidy-pipeline-data-dev"
existing_snowflake_external_id  = "VQB01613_SFCRole=2_tAOOYUX/dtMGqCSl45+ogA2/Rxw="

# ── Warehouse sizing (larger for production workloads) ────────────────────────────
loading_warehouse_size      = "XSMALL"
transforming_warehouse_size = "SMALL"
analytics_warehouse_size    = "MEDIUM"

# ── Snowflake credentials (non-sensitive only) ────────────────────────────────────
# Auth credentials (private key, passphrase, public key) are loaded from prod.env
snowflake_account          = "FOFOXOE-EEB51968"
snowflake_user             = "terraform_svc_user"
snowflake_role             = "ACCOUNTADMIN"
