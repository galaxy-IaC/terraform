## Overview
In this chapter, we're going to achieve AWS VPC with terraform
- Define terraform block and its provider
- Define generic variable of terraform
- Define local tag
- Create VPC with 3-tier architecture(web, app and DB)

## Stage-01: terraform block and provider
### Stage-01-01: terraform block
> define required version to terraform and provider
```
terraform {
    required_version = "~> 1.3.0"
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "4.1.0"
        }
    }
}
```

### Stage-01-02: provider
> define region in file 1-2-providers.tf
```
provider "aws" {
    region = var.aws_region
}
```

## Stage-02: Generic input variable
### Stage-02-01: generic input variable
```
variable "aws_region" {
  description = "Region in AWS"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "environment variable as a prefix"
  type        = string
  default     = "dev"
}

variable "business_division" {
  description = "business division name"
  type        = string
  default     = "infra"
}
```

### Stage-02-02: local value
> define local values for tag
```
locals {
  owners      = var.business_division
  environment = var.environment
  name        = "${var.business_division}-${var.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
}
```

## Stage-03: VPC
### Stage-03-01: probe VPC available zone
> we need to ensure available zone in region, so define a data source
```
data "aws_availability_zones" "available" {
  state = "available"
}
```

### Stage-03-02: achieve VPC within module
```
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.0.0"

  # basic details
  name            = "${local.name}-${var.vpc_name}"
  cidr            = var.vpc_cidr_block
  azs             = data.aws_availability_zones.available.names
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets

  # db subnet
  database_subnets                       = var.vpc_database_subnets
  create_database_subnet_group           = var.vpc_create_database_subnet_group
  create_database_subnet_route_table     = var.vpc_create_database_subnet_route_table
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route      = false

  # NAT gateway
  enable_nat_gateway = var.vpc_enable_nat_gateway
  single_nat_gateway = var.vpc_single_nat_gateway

  # VPC DNS relative parameter
  enable_dns_hostnames = true
  enable_dns_support   = true

  # tag settings
  tags     = local.common_tags
  vpc_tags = local.common_tags

  public_subnet_tags = {
    Type = "Public Subnets"
  }
  private_subnet_tags = {
    Type = "Private Subnets"
  }
  database_subnet_tags = {
    Type = "Private Database Subnets"
  }
}
```

## Stage-04: Execute Terraform Commands
```
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve
Observation: enter into AWS management console
1) Verify VPC
2) Verify Subnets
3) Verify IGW
4) Verify Public Route for Public Subnets
5) Verify no public route for private subnets
6) Verify NAT Gateway and Elastic IP for NAT Gateway
7) Verify NAT Gateway route for Private Subnets
8) Verify no public route or no NAT Gateway route to Database Subnets
9) Verify Tags
```

## Stage-05: Clean-Up
```
$ terraform destroy -auto-approve

$ rm -rf .terraform*
$ rm -rf terraform.tfstate*
```
