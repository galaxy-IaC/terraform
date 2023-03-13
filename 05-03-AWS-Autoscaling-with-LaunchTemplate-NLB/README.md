## Overview
In this chapter, we're going to achieve these targets:
- Based on `01-VPC` to create VPC
- Create security group for EC2, Network Load Balancer
- Create EC2 Instance for bastion
- Create network load balancer with routing by context path
- Create AutoScaling via Launch Template

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in this case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump to
- buy a domain name and host it in AWS Route53 service. I will take `galaxy-aws.top` as example in this case

> NOTE:
> 
> This chapter base on previous `05-02-AWS-Autoscaling-with-LaunchTemplate`
> 
> So, I copy files from that then modify and add related files to achieve function.
> 
> I just only slightly change function and won't present replicated content at before chapter in here.

## Stage 01: Change or Add new function
### Stage-01-01: DNS Registration
> Register domain name for Autoscaling to Network Load Balancer
```
resource "aws_route53_record" "apps_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "nlb.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}
```

### Stage-01-02: Network Load Balancer
> Create NLB
```
# network load balancer with terraform 
module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.0.0"

  name_prefix        = "mynlb-"
  load_balancer_type = "network"

  # network
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # TCP Listener
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 0
    }
  ]

  #  TLS Listener
  https_listeners = [
    {
      port               = 443
      protocol           = "TLS"
      certificate_arn    = module.acm.acm_certificate_arn
      target_group_index = 0
    },
  ]

  # Target Groups
  target_groups = [
    {
      name_prefix          = "app1-"
      backend_protocol     = "TCP"
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
      }
    },
  ]

  # nlb tags
  tags = local.common_tags
}
```

### Stage-01-03: Autoscaling
> Create Autoscaling within Launch Template which associate NLB
```
resource "aws_autoscaling_group" "my_asg" {
  name_prefix = "myasg-"

  desired_capacity = 2
  max_size         = 10
  min_size         = 2

  vpc_zone_identifier = module.vpc.private_subnets
  target_group_arns = module.nlb.target_group_arns

  health_check_type = "EC2"

  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = aws_launch_template.my_launch_template.latest_version
  }

  # Instance Refresh
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["desired_capacity"]
  }

  tag {
    key                 = "Owners"
    value               = "Web-Team"
    propagate_at_launch = true
  }
}
```

### Stage-01-04: Autoscaling TTSP
> NOTE:
> 
> Just only define policy to based on CPU utilization since network load balancer isn't applicable to policy of target request 
```
resource "aws_autoscaling_policy" "avg_cpu_policy_greater_than_xx" {
  name = "avg-cpu-policy-greater-than-xx"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = module.autoscaling.autoscaling_group_id
  estimated_instance_warmup = 180
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
```

## Stage 02: Execute Terraform Commands
```
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve
```

## Stage 03: Verification
- Confirm SNS Subscription in your email
- Verify EC2 Instances
- Verify Launch Templates (High Level)
- Verify Autoscaling Group (High Level)
- Verify Network Load Balancer
- Access and Test
```
# Access and Test with Port 80 - TCP Listener
http://nlb.galaxy-aws.top
http://nlb.galaxy-aws.top/app1/index.html
http://nlb.galaxy-aws.top/app1/metadata.html

# Access and Test with Port 443 - TLS Listener
https://nlb.galaxy-aws.top
https://nlb.galaxy-aws.top/app1/index.html
https://nlb.galaxy-aws.top/app1/metadata.html
```

## Stage 04: Clean Up
```
$ terraform destroy -auto-approve

$ rm -rf .terraform*
$ rm -rf terraform.tfstate*
```
