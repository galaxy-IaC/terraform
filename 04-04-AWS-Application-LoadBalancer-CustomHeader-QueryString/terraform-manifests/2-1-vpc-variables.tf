# VPC input variables
variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "myvpc"
}

variable "vpc_cidr_block" {
  description = "VPC CIDR BLOCK"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_public_subnets" {
  description = "VPC Public Subnet"
  type        = list(string)
  default = [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24",
    "10.0.104.0/24",
    "10.0.105.0/24",
    "10.0.106.0/24",
    "10.0.107.0/24",
    "10.0.108.0/24"
  ]
}

variable "vpc_private_subnets" {
  description = "VPC Private Subnet"
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24",
    "10.0.5.0/24",
    "10.0.6.0/24",
    "10.0.7.0/24",
    "10.0.8.0/24"
  ]
}

variable "vpc_database_subnets" {
  description = "VPC Database Subnets"
  type        = list(string)
  default = [
    "10.0.151.0/24",
    "10.0.152.0/24",
    "10.0.153.0/24",
    "10.0.154.0/24",
    "10.0.155.0/24",
    "10.0.156.0/24",
    "10.0.157.0/24",
    "10.0.158.0/24"
  ]
}

variable "vpc_create_database_subnet_group" {
  description = "whether create database subnet group"
  type        = bool
  default     = true
}

variable "vpc_create_database_subnet_route_table" {
  description = "whether create database subnet route table"
  type        = bool
  default     = true
}

variable "vpc_enable_nat_gateway" {
  description = "whether enable NAT gateway for private subnet"
  type        = bool
  default     = true
}

variable "vpc_single_nat_gateway" {
  description = "whether enable only single NAT gateway in one availability"
  type        = bool
  default     = true
}