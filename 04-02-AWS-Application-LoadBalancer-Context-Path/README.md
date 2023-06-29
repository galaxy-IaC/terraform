## Overview
In this chapter, we're going to achieve these targets:
- Based on `02-EC2Instance-SecurityGroup` chapter to create VPC with 3-tier architecture
- Create security group for application load balancer
- Create EC2 Instance which are bastion and private host
- Create application load balancer with routing by context path

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in this case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump to
- buy a domain name and host it in AWS Route53 service. I will take `galaxy-aws.top` as example in this case

> NOTE:
> This chapter base on early `04-01-AWS-Application-LoadBalancer-Basic`.
> So, I copy relevant files from that. only show new updated change or function and won't present replicated content in early chapter.


## Stage-01: Create Security group
> Create security group which is capable `https` protocol
```
module "loadbalancer_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name        = "loadbalancer-sg"
  description = "Security Group with HTTP open for entire Internet (IPv4 CIDR), egress ports are all world open"
  vpc_id      = module.vpc.vpc_id

  # ingress rules
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
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

## Stage-02: Create Private host
> According to different path in alb, should define private host separately.

```
# APP1
module "ec2_private_app1" {
  depends_on = [module.vpc]

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"

  count = var.private_instance_count

  name              = "${var.environment}-vm-app1-${count.index}"
  ami               = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  availability_zone = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 })[count.index % length(keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 }))]
  #monitoring = true
  vpc_security_group_ids = [module.private_sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  user_data              = file("${path.module}/app1-install.sh")

  # tags
  tags = local.common_tags
}
```

```
# APP2
module "ec2_private_app2" {
  depends_on = [module.vpc]

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"

  count = var.private_instance_count

  name              = "${var.environment}-vm-app2-${count.index}"
  ami               = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  availability_zone = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 })[count.index % length(keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 }))]
  #monitoring = true
  vpc_security_group_ids = [module.private_sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  user_data              = file("${path.module}/app2-install.sh")

  # tags
  tags = local.common_tags
}
```

## Stage-03: DNS and certificate
### Stage-03-01: DNS Register
> Register domain name for ALB in Route53 Service of AWS
```
resource "aws_route53_record" "apps_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "apps.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}
```

> Define data to query DNS domain name
```
data "aws_route53_zone" "mydomain" {
  name = "galaxy-aws.top"
}

output "mydomain_zoneid" {
  value = "data.aws_route53_zone.mydomain.zone_id"
}

output "mydomain_name" {
  value = "data.aws_route53_zone.mydomain.name"
}
```

### Stage-03-02: Certificate
> Create certificate for domain
```
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "3.0.0"

  domain_name = trimsuffix(data.aws_route53_zone.mydomain.name, ".")
  zone_id     = data.aws_route53_zone.mydomain.zone_id

  subject_alternative_names = [
    "*.galaxy-aws.top"
  ]

  tags = local.common_tags
}

# output ACM certificate ARN
output "acm_certificate_arn" {
  value = module.acm.acm_certificate_arn
}
```

## Stage-04: Application Load balancer
We're going to achieve these purpose:
- Fixed Response if access to `/*`
- Specify `app1` path in ALB will go to APP1 instance: `http://apps.galaxy-aws.top/app1/index.html`
- Specify `app2` path in ALB will go to APP2 instance: `http://apps.galaxy-aws.top/app2/index.html`
- Redirect to `HTTPS` as default if URL beginning with `HTTP`

### Stage-04-01: HTTP redirection
```
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
```

### Stage-04-02: HTTPS listener
- associate SSL Certificate
- fixed response if access root path `/*`
```
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
```

### Stage-04-03: HTTPS listener rules
> define path access respectively
```
  https_listener_rules = [
    {
      https_listener_index = 0
      actions = [
        {
          type               = "forward"
          target_group_index = 0
        }
      ]
      conditions = [{
        path_patterns = ["/app1*"]
      }]
    },

    {
      https_listener_index = 0
      actions = [
        {
          type               = "forward"
          target_group_index = 1
        }
      ]
      conditions = [{
        path_patterns = ["/app2*"]
      }]
    },
  ]
```

## Stage-05: Execute Terraform Commands
```
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve

# Verify
Observation: 
1. Verify EC2 Instances for App1
2. Verify EC2 Instances for App2
3. Verify Load Balancer SG - Primarily SSL 443 Rule
4. Verify ALB Listener - HTTP:80 - Should contain a redirect from HTTP to HTTPS
5. Verify ALB Listener - HTTPS:443 - Should contain 3 rules 
5.1 /app1* to app1-tg 
5.2 /app2* to app2-tg 
5.3 /* return Fixed response
6. Verify ALB Target Groups App1 and App2, Targets (should be healthy) 
5. Verify SSL Certificate (Certificate Manager)
6. Verify Route53 DNS Record

# Test (Domain will be different based on your registered domain)
# Note: All the below URLS shoud redirect from HTTP to HTTPS
1. Fixed Response: http://apps.galaxy-aws.top   
2. App1 Landing Page: http://apps.galaxy-aws.top/app1/index.html
3. App1 Metadata Page: http://apps.galaxy-aws.top/app1/metadata.html
4. App2 Landing Page: http://apps.galaxy-aws.top/app2/index.html
5. App2 Metadata Page: http://apps.galaxy-aws.top/app2/metadata.html
```

## Stage-06: Clean Up
```
# Terraform Destroy
terraform destroy -auto-approve

# Delete files
rm -rf .terraform*
rm -rf terraform.tfstate*
```
