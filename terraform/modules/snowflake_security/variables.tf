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

variable "shared_rsa_public_key" {
  description = "Shared RSA public key for service users"
  type        = string
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
  description = "RAW schema name"
}

variable "silver_schema_name" {
  type        = string
  description = "SILVER schema name "
}

variable "gold_schema_name" {
  type        = string
  description = "GOLD"
}

variable "csv_file_format_name" {
  type    = string
  default = "CSV_FORMAT"
}

variable "stage_dependency_placeholder" {
  description = "Output from foundation module to enforce stage creation ordering."
  type        = any
  default     = null
}
