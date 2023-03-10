# Application Load Balancer(ALB) by terraform module
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.0.0"

  name               = "${local.name}-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.loadbalancer_sg.security_group_id]

  # listeners
  http_tcp_listeners = [
    {
      port     = 80
      protocol = "HTTP"
      target_group_index = 0
    }
  ]

  # target groups
  target_groups = [
    # app1 target group
    {
      name_prefix          = "app1-"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/app1/index.html"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
      protocol_version = "HTTP1"

      # targets in app1 target group
      targets = {
        my_app1_vm1 = {
          target_id = module.ec2_private[0].id
          port      = 80
        },
        my_app1_vm2 = {
          target_id = module.ec2_private[1].id
          port      = 80
        }
      }

      tags = local.common_tags
    }
  ]

  # application loadbalancer tags
  tags = local.common_tags
}