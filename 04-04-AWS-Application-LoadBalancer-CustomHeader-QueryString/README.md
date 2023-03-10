## Overview
In this chapter, we're going to achieve these targets:
- Based on `01-VPC` chapter to create VPC with 3-tier architecture
- Create security group for application load balancer
- Create EC2 Instance which are bastion and private host
- Create application load balancer with routing by customer header

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in this case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump log file to
- buy a domain name and host it in AWS Route53 service. I will take `galaxy-aws.top` as example in this case

> NOTE: 
> 
> This branch base on previous `04-03-AWS-Application-LoadBalancer-HostHeader` chapter
>
> So, you could copy files from that then add or modify related files to achieve function for this one.
> 
> I just slightly change content for related function in this chapter and won't present replicated content at before one in here.


## Stage-01: Change Log
### Stage-01-01: DNS
> NOTE: change to new domain name for ALB and customer hoster

```
resource "aws_route53_record" "apps_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "myapp.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app1_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "module.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}
```

### Stage-01-02: ALB for customer header
> Change to multiple rules of ALB
We're going to achieve these purpose:
- Rule-1: custom header, my-app-1 should go to app1 EC2 instance
- Rule-2: custom header, my-app-2 should go to app2 EC2 instance
- Rule-3: query string, q=terraform will redirect to google for search
- Rule-4: host header, `module.galaxy-aws.top` will redirect to `registry.terraform.io/browse/modules`

```
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
```

```
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
```

```
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
```

```
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
```

## Stage-02: Execute Terraform Commands and Verification
### Stage-02-01: Run terraform commands
```
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve
```

### Stage-02-02: Verification
> Verify rule-1 and rule-2
Go to [restninja](https://gitee.com/link?target=https%3A%2F%2Frestninja.io) for test
  - protocol: GET
  - address bar: `https://myapp.galaxy-aws.top` 
  - click `headers` (it should be default)
    - change `header` to `custom-header`
    - replace `value` to `myapp1` or `my-app-1`
    - press `send` button
You will see the `app1` page which expected as we defined it above `https_listener_rules`

Follow the same action just value to `myapp2` or `my-app-2` We will get the same result.

> Verify Rule-3
Test query string, input `q=terraform` string in URL, that will redirect to external google for query.
```
# Verify Rule-3
input URL: https://myapp.galaxy-aws.top/?q=terraform
Observation: 
Should Redirect to https://www.google.com/search?q=terraform
```

> Verify Rule-4
```
# Verify Rule-4
input URL: http://module.galaxy-aws.top
Observation: 
Should redirect to https://registry.terraform.io/browse/modules
```

## Stage-03: Clean Up
```
# Terraform Destroy
terraform destroy -auto-approve

# Delete files
rm -rf .terraform*
rm -rf terraform.tfstate*
```
