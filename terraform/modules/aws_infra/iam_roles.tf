# IAM Policy: grants Snowflake access to the S3 Tables bucket (Iceberg),
# the general-purpose project bucket, and API Gateway.
# All Snowflake integrations (storage, external volume, API) share this single role.
resource "aws_iam_policy" "lakehouse_rw_policy" {
  name        = "SnowflakeLakehouseRWPolicy-${var.project_name}-${var.environment}"
  description = "Allows Snowflake to read/write the S3 Tables bucket (Iceberg), the general-purpose project bucket, and invoke API Gateway"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 Tables bucket — Snowflake Iceberg external volume (silver + gold)
      {
        Sid    = "S3TablesReadWrite"
        Effect = "Allow"
        Action = [
          "s3tables:GetTable",
          "s3tables:PutTable",
          "s3tables:DeleteTable",
          "s3tables:GetNamespace",
          "s3tables:PutNamespace",
          "s3tables:DeleteNamespace",
          "s3tables:ListTables",
          "s3tables:ListNamespaces",
          "s3tables:GetTableBucket",
          "s3tables:ListTableBuckets"
        ]
        Resource = [
          "arn:aws:s3tables:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:bucket/${var.lakehouse_bucket_name}",
          "arn:aws:s3tables:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:bucket/${var.lakehouse_bucket_name}/*"
        ]
      },
      # S3 Tables bucket underlying object store access (required for Iceberg writes)
      {
        Sid    = "S3TablesObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.lakehouse_bucket_name}--table-s3*",
          "arn:aws:s3:::${var.lakehouse_bucket_name}--table-s3*/*"
        ]
      },
      # General-purpose project bucket (raw data, scripts, misc artifacts)
      {
        Sid    = "GeneralPurposeBucketReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-data-${var.environment}",
          "arn:aws:s3:::${var.project_name}-data-${var.environment}/*"
        ]
      },
      # API Gateway invoke (for Geoapify external function)
      {
        Sid    = "APIGatewayInvoke"
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = [
          "arn:aws:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*/*/*/*"
        ]
      }
    ]
  })
}

# Shared IAM Role — assumed by Snowflake for storage integration, external volume, and API integration.
#
# EXTERNAL ID STRATEGY:
#   Snowflake generates a UNIQUE external ID per integration object (storage integration,
#   external volume, API integration). Because all three share this single IAM role, we
#   cannot use StringEquals with a single ID. Instead we use StringLike with the common
#   Snowflake-account-scoped prefix (e.g. "VQB01613_SFCRole=2_*"). This is the pattern
#   Snowflake explicitly documents for shared-role setups.
#   See: https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration
resource "aws_iam_role" "snowflake_role" {
  name = "SnowflakeIntegrationRole-${var.project_name}-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.snowflake_iam_user_arn != "" ? var.snowflake_iam_user_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          # StringLike with wildcard suffix allows ALL Snowflake integrations that share
          # this role (storage integration, external volume, API integration) to assume it.
          # Each integration gets a unique suffix; the prefix is stable per Snowflake account.
          StringLike = {
            "sts:ExternalId" = var.snowflake_external_id_prefix
          }
        }
      }
    ]
  })

  tags = {
    Name        = "SnowflakeIntegrationRole"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach the policy to the shared role
resource "aws_iam_role_policy_attachment" "snowflake_s3_attachment" {
  role       = aws_iam_role.snowflake_role.name
  policy_arn = aws_iam_policy.lakehouse_rw_policy.arn
}

# Data sources for region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}