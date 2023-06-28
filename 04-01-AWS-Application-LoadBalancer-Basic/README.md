## Overview
In this chapter, we're going to achieve these targets:
- Based on `02-EC2Instance-SecurityGroup` chapter to create VPC with 3-tier architecture
- Create security group for application load balancer
- Create EC2 Instance which are bastion and private host
- Create application load balancer

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in our case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump to

> NOTE:
> 
> This chapter base on early `02-EC2Instance-SecurityGroup` one.
> So, I just copy relevant files from that and here only add some new updated files related to application load balancer

## Stage-01: Create Security group
> Define related security group for load balancer
```
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
```

## Stage-02: application load balancer
> Define application load balancer within module 
```
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

  tags = local.common_tags
}
```

## Stage-03: miscellaneous
> Add user data file in working directory
```
#! /bin/bash
sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable httpd
sudo service httpd start  
sudo echo '<h1>Welcome to APP-1</h1>' | sudo tee /var/www/html/index.html
sudo mkdir /var/www/html/app1
sudo echo '<!DOCTYPE html> <html> <body style="background-color:rgb(250, 210, 210);"> <h1>Welcome to APP-1</h1> <p>Terraform Demo</p> <p>Application Version: V1</p> </body></html>' | sudo tee /var/www/html/app1/index.html
sudo curl http://169.254.169.254/latest/dynamic/instance-identity/document -o /var/www/html/app1/metadata.html
```

## Stage-04: Execute Terraform Commands and verification
```
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve

# Verify
Observation: 
1. Verify EC2 Instances
2. Verify Load Balancer SG
3. Verify ALB Listeners and Rules
4. Verify ALB Target Groups, Targets (should be healthy) and Health Check settings
5. Access sample app using Load Balancer DNS Name
# Example: from my environment
http://infra-dev-alb-1575108738.ap-northeast-1.elb.amazonaws.com
http://infra-dev-alb-1575108738.ap-northeast-1.elb.amazonaws.com/app1/index.html
http://infra-dev-alb-1575108738.ap-northeast-1.elb.amazonaws.com/app1/metadata.html
```

## Step-05: Clean-Up
```
$ terraform destroy -auto-approve

$ rm -rf .terraform*
$ rm -rf terraform.tfstate*
```
