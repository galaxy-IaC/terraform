# classic load balancer with terraform module
module "elb" {
  source          = "terraform-aws-modules/elb/aws"
  version         = "4.0.0"
  name            = "${local.name}-myelb"
  subnets         = module.vpc.public_subnets
  security_groups = [module.loadbalancer_sg.security_group_id]

  listener = [
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    },
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 81
      lb_protocol       = "HTTP"
    },
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  # ELB attachments
  number_of_instances = var.private_instance_count
  instances           = module.ec2_private.*.id

  # tags
  tags = local.common_tags
}