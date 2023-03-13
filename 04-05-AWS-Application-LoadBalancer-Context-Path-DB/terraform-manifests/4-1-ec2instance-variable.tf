# EC2 instance input variable
variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t2.micro"
}

variable "instance_keypair" {
  description = "AWS EC2 Key pair that need to be associated with EC2 Instance"
  type        = string
  default     = "terraform-key"
}

variable "bastion_instance_count" {
  description = "bastion instances count"
  type        = number
  default     = 2
}

variable "private_instance_count" {
  description = "AWS EC2 Private Instances Count"
  type        = number
  default     = 2
}

variable "app3_port" {
  description = "the port which client will connect in private app3"
  type        = number
  default     = 3306
}

variable "app3_db_name" {
  description = "the DB name which client will connect in private app3"
  type        = string
  default     = "webappdb"
}

variable "app3_db_user" {
  description = "the db user which client will connect in private app3"
  type        = string
  default     = "dbadmin"
}