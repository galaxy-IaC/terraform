# security group for application load balancer
module "loadbalancer_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name        = "loadbalancer-sg"
  description = "Security group with HTTP and specified port open"
  vpc_id      = module.vpc.vpc_id

  # ingress rules
  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  # open specified port to cidr block
  ingress_with_cidr_blocks = [
    {
      from_port   = 81
      to_port     = 81
      protocol    = 6
      description = "Allow Port 81 from internet"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  # egress rules 
  egress_rules = ["all-all"]

  # tags
  tags = local.common_tags
}