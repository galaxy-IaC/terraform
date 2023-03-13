## Overview
In this chapter, we're going to achieve these targets:
- Based on `01-VPC` to create VPC
- Create security group for EC2, application load balancer
- Create EC2 Instance for bastion
- Create Application load balancer
- Create AutoScaling via Launch Configuration

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in this case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump to
- buy a domain name and host it in AWS Route53 service. I will take `galaxy-aws.top` as example in this case

> NOTE:
>
> This chapter base on before `04-02-AWS-Application-LoadBalancer-Context-Path`
>
> So, I copy files from that then modify and add related files to achieve function such like ALB and Autoscaling.
>
> I'm just only going to show related change or function in this file and won't present replicated content at before chapter in here.

## Stage 01: Change or Add new function
### Stage-01-01: New provider
> Add new provider
```
    random = {
      source = "hashicorp/random"
      version = "~> 3.0"
    }
```

> Create random resource
```
resource "random_pet" "this" {
  length = 2
}
```

### Stage-01-02: Add new tag
> Add new tag setting for ASG
```
  asg_tags = [
    {
      key = "Project"
      value = "megasecret"
      propagate_at_launch = true
    },
    {
      key = "foo"
      value = ""
      propagate_at_launch = true
    },
  ]
```

### Stage-01-03: DNS Registration
> Register DNS for ASG
```
resource "aws_route53_record" "apps_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "asg-lc.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}
```

### Stage-01-04: Change ALB
> NOTE:
> 
> We change ALB setting based on branch `04-02-AWS-Application-LoadBalancer-Context-Path`
>
> It's unnecessary to keep `targets` in `target group` 
>
> ASG allocate this ALB to achieve traffic load balance.
>
> ASG take charge of management the lifecycle to EC2 instance.

```
# REMOVE THESE LINES
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
```

### Stage-01-05: Extra Role for ASG
> ASG need role to access IAM service
```
resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = local.name

  # some time it's good for a sleep
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# output
output "service_linked_role_arn" {
  value = aws_iam_service_linked_role.autoscaling.arn
}
```

### Stage-01-06: ASG
> Implement ASG within module
```
module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "4.1.0"

  # Autoscaling group
  name            = "${local.name}-myasg1"
  use_name_prefix = false

  min_size         = 2
  max_size         = 10
  desired_capacity = 2
  # Changed for testing Instance Refresh
  #desired_capacity = 3

  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"

  vpc_zone_identifier     = module.vpc.private_subnets
  service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn

  # associate ALB with ASG
  target_group_arns = module.alb.target_group_arns

  # ASG Lifecycle Hooks
  initial_lifecycle_hooks = [
    {
      name                 = "ExampleStartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                 = "ExampleTerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  # ASG Instance Refresh
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 50
    }
    triggers = ["tag", "desired_capacity", "max_size"]
  }

  # ASG Launch configuration
  lc_name   = "${local.name}-myLaunchConfiguration1"
  use_lc    = true
  create_lc = true

  image_id      = data.aws_ami.amzlinux2.id
  instance_type = var.instance_type
  key_name      = var.instance_keypair
  user_data     = file("${path.module}/app1-install.sh")

  ebs_optimized     = true
  enable_monitoring = true

  security_groups             = [module.private_sg.security_group_id]
  associate_public_ip_address = false

  # spot instance - optional
  spot_price = "0.014"

  # Change for Instance Refresh test
  #spot_price = "0.016"

  # associate another disk
  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp2"
      volume_size           = "20"
    },
  ]

  # root disk property
  root_block_device = [
    {
      delete_on_termination = true
      encrypted             = true
      volume_size           = "15"
      volume_type           = "gp2"
    },
  ]

  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "optional" # At production grade you can change to "required"
  }

  tags = local.asg_tags
}
```

### Stage-01-07: ASG Notification
> Create SNS for ASG
```
# SNS Topic
resource "aws_sns_topic" "myasg_sns_topic" {
  name = "myasg-sns-topic-${random_pet.this.id}"
}

# SNS subscription
resource "aws_sns_topic_subscription" "myasg_sns_topic_subscription" {
  topic_arn = aws_sns_topic.myasg_sns_topic.arn
  protocol  = "email"
  endpoint  = "bingo4933@gmail.com"
}

# create autoscaling notification resource
resource "aws_autoscaling_notification" "myasg_notifications" {
  group_names = [module.autoscaling.autoscaling_group_id]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
  topic_arn = aws_sns_topic.myasg_sns_topic.arn
}
```

### Stage-01-08: ASG TTSP
> Create TTSP for ASG
>
> TTSP: Target Tracking Scaling Policies
```
# policy - 1: based on CPU Utilization of EC2 instance
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

# policy - 2: based on ALB Target Requests
resource "aws_autoscaling_policy" "alb_target_requests_greater_than_yy" {
  name        = "alb-target-requests-greater-than-yy"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = module.autoscaling.autoscaling_group_id
  estimated_instance_warmup = 120
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
    }
    target_value = 10.0
  }
}
```

### Stage-01-09: ASG Scheduled Action
> [UTC Timezone converter](https://www.worldtimebuddy.com/)
```
## action-1: increase capacity due by business time
resource "aws_autoscaling_schedule" "increase_capacity_9am" {
  scheduled_action_name = "increase-capacity-9am"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 8
  # Note: UTC time format, set year value 2030 for demo. you can correct that based on your need
  start_time             = "2030-12-11T09:00:00Z"
  recurrence             = "00 09 * * *"
  autoscaling_group_name = module.autoscaling.autoscaling_group_id
}

## action-2: decrease capacity during non-business hours
resource "aws_autoscaling_schedule" "decrease_capacity_9pm" {
  scheduled_action_name  = "decrease-capacity-9pm"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 2
  start_time             = "2030-12-11T21:00:00Z"
  recurrence             = "00 21 * * *"
  autoscaling_group_name = module.autoscaling.autoscaling_group_id
}
```

## Stage 02: Execute terraform commands
```
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve
```

## Stage 03: Verify and test
### Stage-03-01: Access
```
# Access and Test
http://asg-lc.galaxy-aws.top
http://asg-lc.galaxy-aws.top/app1/index.html
http://asg-lc.galaxy-aws.top/app1/metadata.html
```

### Stage-03-02: Change Autoscaling setting and test
- Test Instance Refresh
  1. Change Desired capacity and test
  2. Uncomment `#desired_capacity = 3` then check arguments in `triggers` , do a instance refresh
```
  # ASG Instance Referesh
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 50
    }
    triggers = ["tag", "desired_capacity"]
  }
```
- Execute Terraform Commands
```
terraform plan

terraform apply -auto-approve

# Observation
1. Consistently monitor the Autoscaling "Activity" and "Instance Refresh" tabs.
2. In close to 5 to 10 minutes, instances will be refreshed
3. Verify EC2 Instances, old will be terminated and new will be created
```

- Change spot_price then refresh again
> In this case, we change `spot_price` for refresh to Instance
```
# Before
  spot_price = "0.014"
# After
  #spot_price = "0.014"
  
CHANGE TO

# Before
  #spot_price = "0.016"
# After
  spot_price = "0.016"
```

- Execute terraform command again
```
terraform plan

terraform apply -auto-approve

# Observation
1. Consistently monitor the Autoscaling "Activity" and "Instance Refresh" tabs.
2. In close to 5 to 10 minutes, instances will be refreshed
3. Verify EC2 Instances, old will be terminated and new will be created
```

### Stage-03-03: Test Autoscaling using Postman
- [Download Postman client and Install](https://www.postman.com/downloads/)
- Create New Collection: terraform
  - go to `Collections` menu in `My Workspace`
  - click `New` button then click `Collection`
    - Rename to `terraform-aws-demo` 
    - Right click it then select `Add Request` 
    - Name it in the appeared tab then input: `Load-Test-ASG` for that request
    - Input URL: `https://asg-lc.galaxy-aws.top/app1/metadata.html`
    - Select `GET` as protocol then click `Send`
    - Click `SAVE` 
  - Return to Collection: `terraform-aws-demo` 
    - Click it
    - Input argument while click `Run` button
      - Iterations: 5000
      - Delay: 5
      - Keep the rest
  - Click `Run terraform-aws-demo` button
- Go back to AWS management console
  - Monitor ASG -> Activity Tab
  - Monitor EC2 -> Instances - To see if new EC2 Instances getting created (Autoscaling working as expected)
  - It might take 5 to 10 minutes to autoscale with new EC2 Instances

## Stage 04: Clean Up
```
# Terraform Destroy
terraform destroy -auto-approve

# Clean-Up Files
rm -rf .terraform*
rm -rf terraform.tfstate*
```
