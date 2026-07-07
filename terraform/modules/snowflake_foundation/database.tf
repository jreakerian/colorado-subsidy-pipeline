# Single database per environment run.
# The database name and schema suffixes are driven by var.db_name and var.environment.
# Run with: terraform apply -var-file=dev.tfvars  OR  -var-file=prod.tfvars

locals {
  schema_suffix = upper(var.environment) # "DEV" or "PROD"
}

resource "snowflake_database" "colorado_crime_db" {
  name                        = var.db_name
  comment                     = "Colorado Subsidy data pipeline — ${upper(var.environment)} environment"
  data_retention_time_in_days = 0
}

# RAW schema — data landing zone
resource "snowflake_schema" "raw" {
  database = snowflake_database.colorado_crime_db.name
  name     = "RAW_${local.schema_suffix}"
  comment  = "Raw data landing zone (${var.environment})"
}

# SILVER schema — cleaned and validated data
resource "snowflake_schema" "silver" {
  database = snowflake_database.colorado_crime_db.name
  name     = "SILVER_${local.schema_suffix}"
  comment  = "Cleaned and validated data (${var.environment})"
}

# GOLD schema — business-ready aggregates
resource "snowflake_schema" "gold" {
  database = snowflake_database.colorado_crime_db.name
  name     = "GOLD_${local.schema_suffix}"
  comment  = "Business-ready aggregated data (${var.environment})"
}