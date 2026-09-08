# ── Environment ───────────────────────────────────────────────────────────────────
# last-ci-test: 2026-09-03
environment  = "dev"
project_name = "colorado-subsidy-pipeline"

# ── Snowflake Database ────────────────────────────────────────────────────────────
# This is the ONLY database created when applying with this file.
db_name = "COLORADO_CRIME_DB"

# ── AWS Resources ─────────────────────────────────────────────────────────────────
aws_region            = "us-east-2"
lakehouse_bucket_name = "co-subsidy-lakehouse-dev"

# ── Warehouse sizing (smaller/cheaper for dev) ────────────────────────────────────
loading_warehouse_size      = "XSMALL"
transforming_warehouse_size = "XSMALL"
analytics_warehouse_size    = "SMALL"

# ── Snowflake credentials (non-sensitive only) ────────────────────────────────────
# Auth credentials (private key, passphrase, public key) are loaded from dev.env
snowflake_account          = "MBJASEX-DLB27711"
snowflake_user             = "terraform_svc_user"
snowflake_role             = "ACCOUNTADMIN"

# These values lock down the IAM role trust policy.
# Because prod reuses the dev AWS infrastructure, we provide a list of ARNs and prefixes
# to trust both the Dev Snowflake account and the Prod Snowflake account.
snowflake_iam_user_arns = [
  "arn:aws:iam::738540809744:user/7b652000-s", # Dev Account User
  "arn:aws:iam::000862407413:user/avu52000-s"] # Prod Account User

# Wildcard prefix covering ALL integrations (storage, external volume, API) that
# share the SnowflakeIntegrationRole. Each integration gets a unique suffix.
snowflake_external_id_prefixes = [
  "EFB20180_SFCRole=2_*", # Dev Account Prefix
  "CGB41232_SFCRole=2_*"] # Prod Account Prefix
