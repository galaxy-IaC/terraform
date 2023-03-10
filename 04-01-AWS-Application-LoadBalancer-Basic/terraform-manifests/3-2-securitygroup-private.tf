# security group for private ec2 instance host
module "private_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name        = "private-sg"
  description = "Security group with HTTP & SSH port"
  vpc_id      = module.vpc.vpc_id

  # ingress rules
  ingress_rules       = ["ssh-tcp", "http-80-tcp"]
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]

  # egress rule
  egress_rules = ["all-all"]

  tags = local.common_tags
}