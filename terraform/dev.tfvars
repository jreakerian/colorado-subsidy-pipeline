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
snowflake_account          = "FOFOXOE-EEB51968"
snowflake_user             = "terraform_svc_user"
snowflake_role             = "ACCOUNTADMIN"

# ── Snowflake ↔ AWS Trust (from DESCRIBE INTEGRATION after initial bootstrap) ─
# These values lock down the IAM role trust policy so only *this* Snowflake
# account can assume the role. They are stable for the lifetime of the integration.
snowflake_external_id  = "VQB01613_SFCRole=2_tAOOYUX/dtMGqCSl45+ogA2/Rxw="
snowflake_iam_user_arn = "arn:aws:iam::724937262037:user/g6qp1000-s"

# Wildcard prefix covering ALL integrations (storage, external volume, API) that
# share the SnowflakeIntegrationRole. Each integration gets a unique suffix;
# the prefix VQB01613_SFCRole=2_ is stable for this Snowflake account.
snowflake_external_id_prefix = "VQB01613_SFCRole=2_*"
