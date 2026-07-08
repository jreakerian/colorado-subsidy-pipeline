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