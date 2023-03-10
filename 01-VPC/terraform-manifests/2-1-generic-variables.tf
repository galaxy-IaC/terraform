# generic variable definition
variable "aws_region" {
  description = "Region in AWS"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "environment variable as a prefix"
  type        = string
  default     = "dev"
}

variable "business_division" {
  description = "business division name"
  type        = string
  default     = "infra"
}
