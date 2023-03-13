variable "aws_region" {
  description = "Region in which AWS resource to be created"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "prefix string"
  type        = string
  default     = "dev"
}

variable "business_division" {
  description = "business division"
  type        = string
  default     = "infra"
}