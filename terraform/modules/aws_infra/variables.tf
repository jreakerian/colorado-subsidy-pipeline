variable "project_name" {
  description = "The core name of the project used for naming resources."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "lakehouse_bucket_name" {
  description = "The globally unique name for the S3 Table bucket housing the Medallion architecture."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the lakehouse infrastructure will be deployed."
  type        = string
  default     = "us-east-2"
}

variable "snowflake_iam_user_arns" {
  description = "List of AWS_IAM_USER_ARNs from DESCRIBE INTEGRATION. Leave empty for initial bootstrap."
  type        = list(string)
  default     = []
}

variable "snowflake_external_id_prefixes" {
  description = "List of wildcard prefixes for sts:ExternalId condition (e.g. 'VQB01613_SFCRole=2_*')."
  type        = list(string)
  default     = ["0000*"]
}
