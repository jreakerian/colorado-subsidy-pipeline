variable "aws_region" {
  description = "The AWS region where the lakehouse infrastructure will be deployed."
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Deployment environment: 'dev' or 'prod'."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

variable "project_name" {
  description = "The core name of the project used for naming resources."
  type        = string
  default     = "colorado-subsidy-pipeline"
}

variable "db_name" {
  description = "Snowflake database name for this environment (e.g. COLORADO_CRIME_DB)."
  type        = string
}

variable "lakehouse_bucket_name" {
  description = "Globally unique name for the S3 Tables bucket (Silver + Gold Iceberg namespaces)."
  type        = string
}

variable "owner_team" {
  description = "The team responsible for this infrastructure."
  type        = string
  default     = "data-engineering"
}

# ── Warehouse sizing ──────────────────────────────────────────────────────────────
variable "loading_warehouse_size" {
  description = "Size for the loading warehouse."
  type        = string
  default     = "XSMALL"
}

variable "transforming_warehouse_size" {
  description = "Size for the transforming warehouse."
  type        = string
  default     = "SMALL"
}

variable "analytics_warehouse_size" {
  description = "Size for the analytics warehouse."
  type        = string
  default     = "MEDIUM"
}

# ── Snowflake provider credentials (never hardcode in main.tf) ────────────────────
variable "snowflake_organization_name" {
  description = "Snowflake organization name (shown in SHOW ORGANIZATIONS)."
  type        = string
  sensitive   = true
}

variable "snowflake_account_name" {
  description = "Snowflake account name (the locator, e.g. EEB51968)."
  type        = string
  sensitive   = true
}

variable "snowflake_user" {
  description = "Snowflake username for the Terraform service account."
  type        = string
  default     = "terraform_svc_user"
}

variable "snowflake_role" {
  description = "Snowflake role for the Terraform service account."
  type        = string
  default     = "ACCOUNTADMIN"
}

# ── Snowflake key-pair auth ───────────────────────────────────────────────────────
variable "snowflake_private_key_path" {
  type        = string
  description = "Absolute path to the RSA private key (.p8) for Snowflake JWT auth."
  sensitive   = true
}

variable "private_key_passphrase" {
  type        = string
  description = "Passphrase to decrypt the Snowflake RSA private key."
  sensitive   = true
}

# ── Snowflake <-> AWS trust bootstrap ────────────────────────────────────────────
variable "snowflake_iam_user_arn" {
  description = "AWS_IAM_USER_ARN from DESCRIBE INTEGRATION. Leave empty for initial bootstrap."
  type        = string
  default     = ""
}

variable "snowflake_external_id" {
  description = "AWS_EXTERNAL_ID from DESCRIBE INTEGRATION. Leave dummy value for initial bootstrap."
  type        = string
  default     = "0000"
}

variable "snowflake_external_id_prefix" {
  description = "Wildcard prefix for sts:ExternalId IAM condition (e.g. 'VQB01613_SFCRole=2_*'). Covers all Snowflake integrations sharing this role. Stable for the lifetime of the Snowflake account."
  type        = string
  default     = "0000*"
}


# ── AWS module toggle ────────────────────────────────────────────────────────────
# Set to false for prod to reuse the existing shared AWS infrastructure instead
# of provisioning new S3 buckets and IAM roles.
variable "deploy_aws_infra" {
  description = "Whether to deploy the aws_infra module. Set to false for prod to reuse shared AWS resources."
  type        = bool
  default     = true
}

# When deploy_aws_infra = false, provide these values from the already-deployed
# dev (or shared) AWS infrastructure so Snowflake modules can reference them.
variable "existing_snowflake_role_arn" {
  description = "ARN of the pre-existing SnowflakeIntegrationRole when deploy_aws_infra = false."
  type        = string
  default     = ""
}

variable "existing_general_purpose_bucket" {
  description = "Name of the pre-existing general-purpose S3 bucket when deploy_aws_infra = false."
  type        = string
  default     = ""
}

variable "existing_snowflake_external_id" {
  description = "Snowflake AWS_EXTERNAL_ID from the pre-existing storage integration when deploy_aws_infra = false."
  type        = string
  default     = ""
}

# ── Service account passwords ─────────────────────────────────────────────────────
variable "airflow_service_password" {
  description = "Password for the Airflow service user in Snowflake."
  type        = string
  sensitive   = true
}

variable "dbt_service_password" {
  description = "Password for the dbt service user in Snowflake."
  type        = string
  sensitive   = true
}

variable "dbt_semantic_service_password" {
  description = "Password for the dbt Semantic Layer service user in Snowflake."
  type        = string
  sensitive   = true
}

variable "metabase_service_password" {
  description = "Password for the Metabase service user in Snowflake."
  type        = string
  sensitive   = true
}
