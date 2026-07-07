# API Integration for Geoapify external function
resource "snowflake_api_integration" "geoapify_integration" {
  name                 = "GEOAPIFY_API_INTEGRATION"
  api_provider         = "aws_api_gateway"
  api_aws_role_arn     = var.role_arn
  api_allowed_prefixes = ["https://a1b2c3d4e5.execute-api.us-east-2.amazonaws.com/prod/"]
  api_blocked_prefixes = []
  enabled              = true
  comment              = "API integration for Geoapify geocoding service"
}

# External function for geocoding
resource "snowflake_external_function" "geocode_address" {
  name                      = "GEOCODE_ADDRESS"
  database                  = var.database_name
  schema                    = var.staging_schema_name
  api_integration           = snowflake_api_integration.geoapify_integration.name
  url_of_proxy_and_resource = "https://a1b2c3d4e5.execute-api.us-east-2.amazonaws.com/prod/geocode"
  return_behavior           = "IMMUTABLE"
  return_type               = "VARIANT"
  max_batch_rows            = 100
  compression               = "GZIP"

  arg {
    name = "address"
    type = "VARCHAR"
  }

  comment = "External function to geocode addresses using Geoapify API"

  lifecycle {
    ignore_changes = [return_type]
  }
}
