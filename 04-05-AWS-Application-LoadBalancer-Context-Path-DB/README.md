## Overview
In this chapter, we're going to achieve these targets:
- Based on before chapter `01-VPC` to create VPC with 3-tier architecture
- Create security group for EC2, application load balancer and RDS 
- Create EC2 Instance which are bastion, private host and APP 
- Application load balancer with routing by context path
- Create RDS

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in this case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump to
- buy a domain name and host it in AWS Route53 service. I will take `galaxy-aws.top` as example in this case

> NOTE:
>
> This chapter base on before `04-02-AWS-Application-LoadBalancer-Context-Path`
>
> So, you could copy files from that then add or modify related files to achieve function.
>
> I'm just only going to show related change or function in this chapter and won't present replicated content at before in here.

## Stage-01: Change or Add new function
### Stage-01-01: Security group for RDS
> Define security group
```
module "rdsdb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name        = "rdsdb-sg"
  description = "Access to MySQL DB for entire VPC CIDR Block"

  # VPC
  vpc_id = module.vpc.vpc_id

  # ingress rule
  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  # egress rule
  egress_rules = ["all-all"]

  # tag
  tags = local.common_tags
}
```

### Stage-01-02: Add related input variable to RDS
```
variable "app3_port" {
  description = "the port which client will connect in private app3"
  type        = number
  default     = 3306
}

variable "app3_db_name" {
  description = "the DB name which client will connect in private app3"
  type        = string
  default     = "webappdb"
}

variable "app3_db_user" {
  description = "the db user which client will connect in private app3"
  type        = string
  default     = "dbadmin"
}
```

### Stage-01-03: Bastion host
> Add `user_data` to bastion host as jumpbox for connection MySQL

```
user_data              = file("${path.module}/jumpbox-install.sh")
```

### Stage-01-04: New private host
> Provision new private host in case to run APP to connect backend database
>
> `templatefile` function render template file to provide user data.
```
module "ec2_private_app3" {
  depends_on = [module.vpc]

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"

  count = var.private_instance_count

  name              = "${var.environment}-vm-app3-${count.index}"
  ami               = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  availability_zone = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 })[count.index % length(keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 }))]
  vpc_security_group_ids = [module.private_sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  user_data              = templatefile("app3-ums-install.tmpl", { rds_db_endpoint = module.rdsdb.db_instance_address, app3_port = var.app3_port, app3_db_name = var.app3_db_name, app3_db_user = var.app3_db_user, app3_pwd = var.db_password })

  # tags
  tags = local.common_tags
}
```

### Stage-01-05: ALB
- Base on before `04-02-AWS-Application-LoadBalancer-Context-Path`
- Add new https listener rule and its target group
```
# rule-3: /db should route to ec2 instance for MySQL client
    {
      https_listener_index = 0
      priority             = 3
      actions = [
        {
          type               = "forward"
          target_group_index = 2
        }
      ]
      conditions = [{
        path_patterns = ["/db*"]
      }]
    },
```

```
# Target group
    {
      name_prefix          = "app3-"
      backend_protocol     = "HTTP"
      backend_port         = 8080
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/login"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
      stickiness = {
        enabled         = true
        cookie_duration = 86400
        type            = "lb_cookie"
      }
      protocol_version = "HTTP1"

      # the targets of app3 target group
      targets = {
        my_app3_vm1 = {
          target_id = module.ec2_private_app3[0].id
          port      = 8080
        },
        my_app3_vm2 = {
          target_id = module.ec2_private_app3[1].id
          port      = 8080
        }
      }

      # tags
      tags = local.common_tags
    },
```

### Stage-01-06: RDS
> Define RDS within module
```
module "rdsdb" {
  source  = "terraform-aws-modules/rds/aws"
  version = "3.0.0"

  identifier = var.db_instance_identifier

  name     = var.database_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  multi_az               = true
  subnet_ids             = module.vpc.database_subnets
  vpc_security_group_ids = [module.rdsdb_sg.security_group_id]

  # DB option
  engine               = "mysql"
  engine_version       = "8.0.20"
  family               = "mysql8.0"
  major_engine_version = "8.0"
  instance_class       = "db.t3.large"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = false

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["general"]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  tags = local.common_tags

  db_instance_tags = {
    "Sensitive" = "high"
  }
  db_option_group_tags = {
    "Sensitive" = "low"
  }
  db_parameter_group_tags = {
    "Sensitive" = "low"
  }
  db_subnet_group_tags = {
    "Sensitive" = "high"
  }
}
```
### Stage-01-07: DNS
> Register DNS
```
resource "aws_route53_record" "apps_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "app-to-db.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}
```

## Stage-02: miscellaneous
> Add user data file in working directory
- app1-install.sh
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

- app2-install.sh
```
#! /bin/bash
sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable httpd
sudo service httpd start  
sudo echo '<h1>Welcome to APP-2</h1>' | sudo tee /var/www/html/index.html
sudo mkdir /var/www/html/app2
sudo echo '<!DOCTYPE html> <html> <body style="background-color:rgb(15, 232, 192);"> <h1>Welcome to APP-2</h1> <p>Terraform Demo</p> <p>Application Version: V1</p> </body></html>' | sudo tee /var/www/html/app2/index.html
sudo curl http://169.254.169.254/latest/dynamic/instance-identity/document -o /var/www/html/app2/metadata.html
```

- app3-ums-install.tmpl
```
#! /bin/bash
sudo amazon-linux-extras enable java-openjdk11
sudo yum clean metadata && sudo yum -y install java-11-openjdk
mkdir /home/ec2-user/app3-usermgmt && cd /home/ec2-user/app3-usermgmt
wget https://gitee.com/bingo4933/temp1/attach_files/1097299/download/usermgmt-webapp.war -P /home/ec2-user/app3-usermgmt 
export DB_HOSTNAME=${rds_db_endpoint}
export DB_PORT=${app3_port}
export DB_NAME=${app3_db_name}
export DB_USERNAME=${app3_db_user}
export DB_PASSWORD=${app3_pwd}
java -jar /home/ec2-user/app3-usermgmt/usermgmt-webapp.war > /home/ec2-user/app3-usermgmt/ums-start.log &
```

- jumpbox-install.sh
```
#! /bin/bash
sudo yum update -y
sudo rpm -e --nodeps mariadb-libs-*
sudo amazon-linux-extras enable mariadb10.5 
sudo yum clean metadata
sudo yum install -y mariadb
sudo mysql -V
sudo yum install -y telnet
```

## Stage-03: Execute Terraform Commands and Verification
### Stage-03-01: Execute command
```
$ terraform init 

$ terraform validate

$ terraform plan -var-file="secrets.tfvars"

$ terraform apply -var-file="secrets.tfvars"
```

### Stage-03-02: Verification
- EC2 Instances App1, App2, App3, Bastion Host
- ALB Listeners and Routing Rules
- ALB Target Groups
- RDS DB

### Stage-03-03: Connect DB and App3
> Connect via jumpbox to DB then verify tables and Content inside
```
# Connect to MySQL DB
mysql -h webappdb.cdljydmxbnly3.ap-northeast-1.rds.amazonaws.com -u dbadmin -p<YOUR_CREDENTIALS>
mysql> show schemas;
mysql> use webappdb;
mysql> show tables;
mysql> select * from user;
```

> Connect to app3 instances
```
# from jumpbox
ssh -i /tmp/terraform-key.pem ec2-user@<App3-Ec2Instance-1-Private-IP>

# Check logs
cd app3-usermgmt
more ums-start.log
```

### Stage-03-04: Access application
```
# App1
https://dns-to-db.galaxy-aws.top/app1/index.html

# App2
https://dns-to-db.galaxy-aws.top/app2/index.html

# App3
https://dns-to-db.galaxy-aws.top/db
Username: admin101
Password: password101
1. Create a user, List User
2. Verify user in DB
```

## Stage-04: Clean Up
```
terraform destroy -auto-approve

rm -rf .terraform*
rm -rf terraform.tfstate
```
