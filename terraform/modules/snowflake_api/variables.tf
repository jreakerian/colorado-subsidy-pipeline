variable "role_arn" {
  description = "ARN of the IAM role for Snowflake to assume"
  type        = string
}

variable "database_name" {
  description = "Name of the Snowflake database"
  type        = string
}

variable "staging_schema_name" {
  description = "Name of the staging schema"
  type        = string
}

variable "geoapify_api_key" {
  description = "Geoapify API key for the GEOCODE_ADDRESS external function. Supply via TF_VAR_geoapify_api_key or a .tfvars file — never hardcode."
  type        = string
  sensitive   = true
}