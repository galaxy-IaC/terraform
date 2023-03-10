## Overview
In this chapter, we're going to achieve these targets:
- Based on `02-EC2Instance-SecurityGroup` chapter to create VPC
- Create security group for classic load balancer
- Create EC2 Instance which are `bastion` and `private` host
- Classic load balancer

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in this case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump log file to

> NOTE:
> 
> This chapter base on `02-EC2Instance-SecurityGroup`
> 
> So, I copy files from that then only add some new change related to classic load balancer

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

## Stage-02: Classic load balancer
> Define classic load balancer module

```
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
```

## Stage-03: miscellaneous
- Add user data file in working directory
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
3. Verify Load Balancer Instances are healthy
4. Access sample app using Load Balancer DNS Name
# Example: from my environment
http://infra-dev-myelb-557211422.ap-northeast-1.elb.amazonaws.com - Will pass
http://infra-dev-myelb-557211422.ap-northeast-1.elb.amazonaws.com:81 - Will pass
```

## Step-05: Clean-Up
```
$ terraform destroy -auto-approve

$ rm -rf .terraform*
$ rm -rf terraform.tfstate*
```
