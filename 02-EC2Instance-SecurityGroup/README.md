## Overview
In this chapter, we're going to achieve these targets:
- Based on `01-VPC` chapter to VPC
- Create security group with terraform module
- Create multiple EC2 Instances within VPC Private Subnet
- Create multiple EC2 Instances within VPC Public Subnet
- Create Elastic IP for bastion host

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in this case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump log file to it

## Stage-01: Create Security group
> Define related security group for bastion and private host

### Stage-01-01: security group rules for bastion host
```
module "public_bastion_sg" {
source  = "terraform-aws-modules/security-group/aws"
version = "4.0.0"

name        = "public-bastion-sg"
description = "Security group to SSH port open for everybody, egress ports are all available"
vpc_id      = module.vpc.vpc_id

# ingress rules
ingress_rules       = ["ssh-tcp"]
ingress_cidr_blocks = ["0.0.0.0/0"]

# egress rule
egress_rules = ["all-all"]

tags = local.common_tags
}
```

### Stage-01-02: security group rules for private host
```
module "private_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name        = "private-sg"
  description = "Security group with HTTP & SSH port, egress ports are all open"
  vpc_id      = module.vpc.vpc_id

  # ingress rules
  ingress_rules       = ["ssh-tcp", "http-80-tcp"]
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]

  # egress rule
  egress_rules = ["all-all"]

  tags = local.common_tags
}
```

## Stage-02: Create EC2 instance
> Define AWS EC2 instance separately within module

### Stage-02-01: bastion EC2 instance
> Assign EC2 instance respectively in different available zone 
```
module "ec2_public" {
  depends_on = [module.vpc]

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"

  count             = var.bastion_instance_count
  name              = "${var.environment}-BastionHost-${count.index}"
  availability_zone = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 })[count.index % length(keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 }))]
  ami               = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  #monitoring = true
  subnet_id              = module.vpc.public_subnets[count.index % length(module.vpc.public_subnets)]
  vpc_security_group_ids = [module.public_bastion_sg.security_group_id]

  # tag
  tags = local.common_tags
}
```

### Stage-02-02: private EC2 instance
```
module "ec2_private" {
  depends_on = [module.vpc]

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.3.0"

  count = var.private_instance_count

  name              = "${var.environment}-vm-${count.index}"
  ami               = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  availability_zone = keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 })[count.index % length(keys({ for az, details in data.aws_ec2_instance_type_offerings.my_ins_type : az => details.instance_types if length(details.instance_types) != 0 }))]
  #monitoring = true
  vpc_security_group_ids = [module.private_sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  user_data              = file("${path.module}/app1-install.sh")

  tags = local.common_tags
}
```

## Stage-03: Assign elastic IP and Use provisioner
### Stage-03-01: Elastic IP
> Resource require `depends_on` 
```
# Create Elastic IP for Bastion Host
resource "aws_eip" "bastion_eip" {
  depends_on = [module.ec2_public, module.vpc]
  count      = var.bastion_instance_count
  instance   = module.ec2_public[count.index].id
  vpc        = true
  tags       = local.common_tags

  # local-exec provisioner which Destroy-Time Provisioner, be Triggered during deletion of Resource
  provisioner "local-exec" {
    command     = "echo Destroy time `date` >> destroy-time-prov.txt"
    working_dir = "local-exec-output-files/"
    when        = destroy
    #on_failure = continue
  }
}

output "elastic_IP_of_instance" {
  value = aws_eip.bastion_eip.*.public_ip
}
```

### Stage-03-02: null resource
> null resource include provisioner to perform task
```
# create a null resource and provisioner
resource "null_resource" "name" {
  depends_on = [module.ec2_public]
  count      = var.bastion_instance_count

  connection {
    type        = "ssh"
    host        = aws_eip.bastion_eip[count.index].public_ip
    user        = "ec2-user"
    password    = ""
    private_key = file("private-key/terraform-key.pem")
  }

  provisioner "file" {
    source = "private-key/terraform-key.pem"
    destination = "/tmp/terraform-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 400 /tmp/terraform-key.pem"
    ]
  }

  provisioner "local-exec" {
    command     = "echo VPC created on `date` and VPC ID: ${module.vpc.vpc_id} >> creation-time-vpc-id.txt"
    working_dir = "local-exec-output-files/"
  }
}
```

## Stage-04: miscellaneous
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

## Stage-05: Execute Terraform Commands and connection
### Stage-05-01: Execute terraform command
```
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve
```

### Stage-05-02: Connect to bastion EC2 instance
> Connect to bastion EC2 instance from local desktop
```
$ ssh -i private-key/terraform-key.pem ec2-user@<PUBLIC_IP_FOR_BASTION_HOST>

# Curl Test for bastion EC2 instance to private EC2 instances
$ curl  http://<Private-Instance-1-Private-IP>
$ curl  http://<Private-Instance-2-Private-IP>
```

> Connect to private EC2 instances from bastion EC2 instance
```
$ ssh -i /tmp/terraform-key.pem ec2-user@<Private-Instance-1-Private-IP>
$ cd /var/www/html
$ ls -lrta
$ curl http://169.254.169.254/latest/user-data
$ cd /var/log
$ more cloud-init-output.log
```

## Stage-06: Clean-Up
```
# Terraform Destroy
terraform destroy -auto-approve

# Clean-Up
rm -rf .terraform*
rm -rf terraform.tfstate*
```
