# This module is mostly self-contained, but we can add variables if needed
variable "environment" {
  description = "Deployment environment: 'dev' or 'prod'. Appended to warehouse names for isolation."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

variable "loading_warehouse_size" {

  description = "Size of the loading warehouse"
  type        = string
  default     = "XSMALL"
}

variable "transforming_warehouse_size" {
  description = "Size of the transforming warehouse"
  type        = string
  default     = "SMALL"
}

variable "analytics_warehouse_size" {
  description = "Size of the analytics warehouse"
  type        = string
  default     = "MEDIUM"
}