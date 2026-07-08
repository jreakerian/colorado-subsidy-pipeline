# S3 Tables bucket for Iceberg external volume (Silver + Gold namespaces)
# NOTE: encryption_configuration is Optional+Computed in AWS provider v6.x (fix for prior inconsistency bug)
resource "aws_s3tables_table_bucket" "data_lake" {
  name = var.lakehouse_bucket_name

  maintenance_configuration = {
    iceberg_unreferenced_file_removal = {
      status = "enabled"
      settings = {
        non_current_days  = 10
        unreferenced_days = 3
      }
    }
  }
}

# S3 Tables Bucket Policy — allows the Snowflake integration role to interact with S3 Tables.
# Unlike standard S3 buckets, S3 Tables buckets require an explicit table bucket policy 
# to delegate permissions to external roles (like Snowflake's assumed role).
resource "aws_s3tables_table_bucket_policy" "lakehouse_policy" {
  table_bucket_arn = aws_s3tables_table_bucket.data_lake.arn

  resource_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSnowflakeIntegration"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.snowflake_role.arn
        }
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
          aws_s3tables_table_bucket.data_lake.arn,
          "${aws_s3tables_table_bucket.data_lake.arn}/*"
        ]
      }
    ]
  })
}

# Raw namespace — unprocessed Iceberg tables
resource "aws_s3tables_namespace" "raw" {
  table_bucket_arn = aws_s3tables_table_bucket.data_lake.arn
  namespace        = "raw"
}

# Silver namespace — cleaned/validated Iceberg tables
resource "aws_s3tables_namespace" "silver" {
  table_bucket_arn = aws_s3tables_table_bucket.data_lake.arn
  namespace        = "silver"
}

# Gold namespace — business-ready Iceberg tables
resource "aws_s3tables_namespace" "gold" {
  table_bucket_arn = aws_s3tables_table_bucket.data_lake.arn
  namespace        = "gold"
}