# PUBLIC BASTION
output "public_bastion_sg_group_id" {
  description = "The ID of the security group"
  value       = module.public_bastion_sg.security_group_id
}

output "public_bastion_sg_group_vpc_id" {
  description = "The VPC ID"
  value       = module.public_bastion_sg.security_group_vpc_id
}


output "public_bastion_sg_group_name" {
  description = "The name of the security group"
  value       = module.public_bastion_sg.security_group_name
}

# PRIVATE EC2 INSTANCE
output "private_sg_group_id" {
  description = "The ID of the security group"
  value       = module.private_sg.security_group_id
}

output "private_sg_group_vpc_id" {
  description = "The VPC ID"
  value       = module.private_sg.security_group_vpc_id
}

output "private_sg_group_name" {
  description = "The name of the security group"
  value       = module.private_sg.security_group_name
}

# loadbalancer Security Group Outputs
## loadbalancer_sg_group_id
output "loadbalancer_sg_group_id" {
  description = "The ID of the security group"
  value       = module.loadbalancer_sg.security_group_id
}

## loadbalancer_sg_group_vpc_id
output "loadbalancer_sg_group_vpc_id" {
  description = "The VPC ID"
  value       = module.loadbalancer_sg.security_group_vpc_id
}

## loadbalancer_sg_group_name
output "loadbalancer_sg_group_name" {
  description = "The name of the security group"
  value       = module.loadbalancer_sg.security_group_name
}