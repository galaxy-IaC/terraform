# terraform for AWS RDS Database input variable

# DB Name
variable "database_name" {
  description = "AWS RDS Database name"
  type        = string
  default     = "webappdb"
}

# DB Instance Identifier
variable "db_instance_identifier" {
  description = "AWS RDS Database Instance identifier"
  type        = string
  default     = "webappdb"
}

# DB Username - Enable Sensitive flag
variable "db_username" {
  description = "AWS RDS Database Administrator Username"
  type        = string
  default     = "dbadmin"
}

# DB credential
variable "db_password" {
  description = "DB credential"
  type        = string
  sensitive   = true
}