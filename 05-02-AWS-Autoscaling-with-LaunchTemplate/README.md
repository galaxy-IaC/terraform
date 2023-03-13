## Overview
In this chapter, we're going to achieve these targets:
- Based on `01-VPC` to create VPC
- Create security group for EC2, application load balancer
- Create EC2 Instance for bastion
- Create application load balancer
- Create AutoScaling within Launch Template

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in this case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump to
- buy a domain name and host it in AWS Route53 service. I will take `galaxy-aws.top` as example in this case

> NOTE:
> 
> This chapter base on previous `05-01-AWS-Autoscaling-with-LaunchConfiguration`
> 
> So, I copy files from that then modify and add related files to achieve function.
>
> I'm just only going to show related change or function in this and won't present replicated content at before chapter in here.

## Stage 01: Change or Add new function
### Stage-01-01: DNS Registration
> Register domain name for ASG launch template
```
resource "aws_route53_record" "apps_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "asg-lt.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}
```

### Stage-01-02: ASG with Launch Template
> Define Launch Template
```
resource "aws_launch_template" "my_launch_template" {
  name          = "my-launch-template"
  description   = "my launch template"
  image_id      = data.aws_ami.amzlinux2.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.private_sg.security_group_id]
  key_name               = var.instance_keypair
  user_data              = filebase64("${path.module}/app1-install.sh")

  ebs_optimized = true
  update_default_version = true
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {   
      volume_size           = 20
      delete_on_termination = true
      volume_type           = "gp2"
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "myasg"
    }
  }
}
```

> Create ASG via Launch Template
```
resource "aws_autoscaling_group" "my_asg" {
  name_prefix = "myasg-"

  desired_capacity = 2
  max_size         = 10
  min_size         = 2

  vpc_zone_identifier = module.vpc.private_subnets

  target_group_arns = module.alb.target_group_arns
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

## Stage 02:Execute Terraform Commands
```
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve
```

## Stage 03: Verification and test
- Access Test
```
# Access
http://asg-lt.galaxy-aws.top
http://asg-lt.galaxy-aws.top/app1/index.html
http://asg-lt.galaxy-aws.top/app1/metadata.html
```

- Test instance refresh
> update launch template then verify
```
# Before
    ebs {
      volume_size = 10 
      #volume_size = 20   
      delete_on_termination = true
      volume_type = "gp2"
     }

# After
    ebs {
      #volume_size = 10 
      volume_size = 20    
      delete_on_termination = true
      volume_type = "gp2"
     }
```

> Then, execute terraform command again
```
$ terraform plan

$ terraform apply -auto-approve

# Observation
1. Consistently monitor the Autoscaling "Activity" and "Instance Refresh" tabs.
2. In close to 5 to 10 minutes, instances will be refreshed
3. Verify EC2 Instances, old will be terminated and new will be created
```

## Stage 04: Clean Up
```
$ terraform destroy -auto-approve

$ rm -rf .terraform*
$ rm -rf terraform.tfstate*
```
