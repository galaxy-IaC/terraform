# application load balancer with terraform 
# access routed by customer header
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.0.0"

  name               = "${local.name}-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.loadbalancer_sg.security_group_id]

  # Listeners
  # HTTP redirect to HTTPS
  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  # HTTPS listener
  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = module.acm.acm_certificate_arn
      action_type     = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        message_body = "Fixed Static message -for root context"
        status_code  = "200"
      }
    }
  ]

  # HTTPS listener rules
  https_listener_rules = [
    # Rule-1: custom-header, myapp1 should go to App1 EC2 Instances
    {
      https_listener_index = 0
      priority             = 1
      actions = [
        {
          type               = "forward"
          target_group_index = 0
        }
      ]
      conditions = [{
        http_headers = [{
          http_header_name = "custom-header"
          values           = ["app-1", "app1", "my-app-1", "myapp1", "myapp-1"]
        }]
      }]
    },

    # Rule-2: custom-header, myapp2 should go to App2 EC2 Instances
    {
      https_listener_index = 0
      priority             = 2
      actions = [
        {
          type               = "forward"
          target_group_index = 1
        }
      ]
      conditions = [{
        http_headers = [{
          http_header_name = "custom-header"
          values           = ["app-2", "app2", "my-app-2", "myapp2", "myapp-2"]
        }]
      }]
    },

    # Rule-3: Query String, q equal to terraform redirect to https://www.google.com
    {
      https_listener_index = 0
      priority             = 3
      actions = [{
        type        = "redirect"
        status_code = "HTTP_302"
        host        = "www.google.com"
        path        = "/search"
        query       = ""
        protocol    = "HTTPS"
      }]
      conditions = [{
        query_strings = [{
          key   = "q"
          value = "terraform"
        }]
      }]
    },

    # Rule-4: custom host header
    {
      https_listener_index = 0
      priority             = 4
      actions = [{
        type        = "redirect"
        status_code = "HTTP_302"
        host        = "registry.terraform.io"
        path        = "/browse/modules"
        query       = ""
        protocol    = "HTTPS"
      }]
      conditions = [{
        host_headers = ["module.galaxy-aws.top"]
      }]
    },     
  ]

  # Target Groups
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

      # the targets of app1 target group
      targets = {
        my_app1_vm1 = {
          target_id = module.ec2_private_app1[0].id
          port      = 80
        },
        my_app1_vm2 = {
          target_id = module.ec2_private_app1[1].id
          port      = 80
        }
      }

      # tags
      tags = local.common_tags
    },

    # app2 target group
    {
      name_prefix          = "app2-"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/app2/index.html"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
      protocol_version = "HTTP1"

      # the targets of app2 target group
      targets = {
        my_app2_vm1 = {
          target_id = module.ec2_private_app2[0].id
          port      = 80
        },
        my_app2_vm2 = {
          target_id = module.ec2_private_app2[1].id
          port      = 80
        }
      }

      # tags
      tags = local.common_tags
    }
  ]

  # alb tags
  tags = local.common_tags
}