# security group for public bastion host
module "public_bastion_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name        = "public-bastion-sg"
  description = "Security group to SSH port open for everybody, egress ports are all available"
  vpc_id      = module.vpc.vpc_id

  # ingress rules
  ingress_rules       = ["ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  # egress rule
  egress_rules = ["all-all"]

  tags = local.common_tags
}