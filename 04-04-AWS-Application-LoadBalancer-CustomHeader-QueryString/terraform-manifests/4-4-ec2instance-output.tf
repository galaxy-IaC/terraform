# PUBLIC INSTANCE
output "ec2_bastion_public_instance_ids" {
  description = "List of IDs of instances"
  value       = module.ec2_public.*.id
}

output "ec2_bastion_public_ip" {
  description = "List of public IP addresses assigned to the instances"
  value       = module.ec2_public.*.public_ip
}

# PRIVATE INSTANCE
# App1 - Private EC2 Instance
output "app1_ec2_private_instance_ids" {
  description = "List of IDs of App1 instances"
  value       = [for ec2private in module.ec2_private_app1 : ec2private.id]
}

output "app1_ec2_private_ip" {
  description = "List of private IP addresses assigned to the App1 instances"
  value       = [for ec2private in module.ec2_private_app1 : ec2private.private_ip]
}

# App2 - Private EC2 Instance
output "app2_ec2_private_instance_ids" {
  description = "List of IDs of App2 instances"
  value       = [for ec2private in module.ec2_private_app2 : ec2private.id]
}

output "app2_ec2_private_ip" {
  description = "List of private IP addresses assigned to the App2 instances"
  value       = [for ec2private in module.ec2_private_app2 : ec2private.private_ip]
}