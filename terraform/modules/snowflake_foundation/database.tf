# Single database per environment run.
# The database name is driven by var.db_name and var.environment.
# Run with: terraform apply -var-file=dev.tfvars  OR  -var-file=prod.tfvars

resource "snowflake_database" "colorado_crime_db" {
  name                        = "${upper(var.db_name)}_${upper(var.environment)}"
  comment                     = "Colorado Subsidy data pipeline — ${upper(var.environment)} environment"
  
  # Best practice: 0 days retention for DEV to save storage costs, 1+ days for PROD fail-safe
  data_retention_time_in_days = lower(var.environment) == "prod" ? 1 : 0
}

resource "snowflake_schema" "raw" {
  database = snowflake_database.colorado_crime_db.name
  name     = "RAW"
  comment  = "Raw data landing zone (${var.environment})"
}

resource "snowflake_schema" "silver" {
  database = snowflake_database.colorado_crime_db.name
  name     = "SILVER"
  comment  = "Cleaned and validated data (${var.environment})"
}

resource "snowflake_schema" "gold" {
  database = snowflake_database.colorado_crime_db.name
  name     = "GOLD"
  comment  = "Business-ready aggregated data (${var.environment})"
}