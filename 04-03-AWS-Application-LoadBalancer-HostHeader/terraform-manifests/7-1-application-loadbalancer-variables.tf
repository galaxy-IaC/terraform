# Terraform AWS Application Load Balancer Variables
# App1 DNS Name
variable "app1_dns_name" {
  description = "App1 DNS Name"
  type        = string
  default     = "app1.galaxy-aws.top"

}

# App2 DNS Name
variable "app2_dns_name" {
  description = "App2 DNS Name"
  type        = string
  default     = "app2.galaxy-aws.top"
}