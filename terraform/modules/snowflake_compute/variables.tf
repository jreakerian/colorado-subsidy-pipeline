# This module is mostly self-contained, but we can add variables if needed
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