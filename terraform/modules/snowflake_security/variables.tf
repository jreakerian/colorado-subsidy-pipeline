variable "loading_warehouse_name" {
  description = "Name of the loading warehouse"
  type        = string
}

variable "transforming_warehouse_name" {
  description = "Name of the transforming warehouse"
  type        = string
}

variable "analytics_warehouse_name" {
  description = "Name of the analytics warehouse"
  type        = string
}

variable "airflow_service_password" {
  description = "Password for Airflow service user"
  type        = string
  sensitive   = true
}

variable "dbt_service_password" {
  description = "Password for the dbt service user"
  type        = string
  sensitive   = true
}

variable "dbt_semantic_service_password" {
  description = "Password for the dbt Semantic Layer service user"
  type        = string
  sensitive   = true
}

variable "metabase_service_password" {
  description = "Password for the Metabase service user"
  type        = string
  sensitive   = true
}

# ── Database & schema inputs (passed from snowflake_foundation outputs) ───────────
# These variables create the Terraform dependency graph so that grants are always
# created after databases/schemas and destroyed before them.

variable "db_name" {
  type        = string
  description = "Snowflake database name for this environment"
}

variable "raw_schema_name" {
  type        = string
  description = "RAW schema name (e.g. RAW_DEV or RAW_PROD)"
}

variable "silver_schema_name" {
  type        = string
  description = "SILVER schema name (e.g. SILVER_DEV or SILVER_PROD)"
}

variable "gold_schema_name" {
  type        = string
  description = "GOLD schema name (e.g. GOLD_DEV or GOLD_PROD)"
}

variable "csv_file_format_name" {
  type    = string
  default = "CSV_FORMAT"
}

variable "parquet_file_format_name" {
  type    = string
  default = "PARQUET_FORMAT"
}

variable "stage_dependency_placeholder" {
  description = "Output from foundation module to enforce stage creation ordering."
  type        = any
  default     = null
}