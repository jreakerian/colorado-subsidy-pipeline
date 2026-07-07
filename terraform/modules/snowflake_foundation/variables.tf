variable "environment" {
  description = "Deployment environment: 'dev' or 'prod'. Drives schema name suffixes."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

variable "db_name" {
  description = "Snowflake database name for this environment (e.g. COLORADO_CRIME_DB_DEV)"
  type        = string
}

variable "role_arn" {
  description = "ARN of the shared SnowflakeIntegrationRole for all Snowflake-to-AWS integrations"
  type        = string
}

variable "general_purpose_bucket" {
  description = "Name of the general-purpose project S3 bucket (raw uploads, scripts, misc)"
  type        = string
}

variable "table_bucket_name" {
  description = "Name of the S3 Tables bucket used as the Iceberg external volume base"
  type        = string
}

variable "table_bucket_arn" {
  description = "ARN of the S3 Tables bucket for the Medallion architecture"
  type        = string
}

variable "snowflake_external_id" {
  description = "The AWS_EXTERNAL_ID provided by Snowflake after DESCRIBE INTEGRATION"
  type        = string
}
