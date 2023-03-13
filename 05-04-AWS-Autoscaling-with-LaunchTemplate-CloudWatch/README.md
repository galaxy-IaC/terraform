## Overview
In this chapter, we're going to achieve these targets:
- Based on `01-VPC` to create VPC
- Create security group for EC2 instance and load balancer
- Create EC2 Instance
- Create Application load balancer
- Create Autoscaling with Launch Template
- Create Cloud Watch Alarm to ALB/ASG/Synthetic

## Pre-requisite
- prepare your aws key pair file and put into `private-key` folder, for example `terraform-key.pem` in this case
- prepare folder `local-exec-output-files` where local-exec provisioner will dump log file to it
- buy a domain name and host it in AWS Route53 service. I will take `galaxy-aws.top` as example in this case

> NOTE:
> 
> This chapter base on before `05-02-AWS-Autoscaling-with-LaunchTemplate` 
> 
> So, I copy files from that then modify and add related files to achieve function.
> 
> I just only slightly change and add cloud watch function and won't present replicated content at before chapter in here.

## Stage 01: Change or Add new function
### Stage-01-01: DNS Registration
> Register domain name for Cloud Watch
```
resource "aws_route53_record" "apps_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "cloudwatch.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}
```

### Stage-01-02: IAM and S3 to Cloud Watch
> Create IAM role and S3 bucket
```
# AWS IAM Policy
resource "aws_iam_policy" "cw_canary_iam_policy" {
  name        = "cloudwatch-canary-iam-policy"
  path        = "/"
  description = "CloudWatch Canary Synthetic IAM Policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : "cloudwatch:PutMetricData",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "cloudwatch:namespace" : "CloudWatchSynthetics"
          }
        }
      },
      {
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "logs:CreateLogStream",
          "s3:ListAllMyBuckets",
          "logs:CreateLogGroup",
          "logs:PutLogEvents",
          "s3:GetBucketLocation",
          "xray:PutTraceSegments"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# AWS IAM Role
resource "aws_iam_role" "cw_canary_iam_role" {
  name        = "cw-canary-iam-role"
  description = "CloudWatch Synthetics lambda execution role for running canaries"
  path        = "/service-role/"
  assume_role_policy  = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  managed_policy_arns = [aws_iam_policy.cw_canary_iam_policy.arn]
}

# Create S3 Bucket
resource "aws_s3_bucket" "cw_canary_bucket" {
  bucket        = "cw-canary-bucket-${random_pet.this.id}"
  bucket_prefix = "galaxy-aws-"
  force_destroy = true

  tags = {
    Name        = "galaxy bucket"
    Environment = "infra"
  }
}

resource "aws_s3_bucket_acl" "data" {
  bucket = aws_s3_bucket.cw_canary_bucket.id
  acl    = "private"
}
```

### Stage-01-03: ALB alarm of Cloud Watch
> Alert if HTTP 4xx happen more than threshold value
```
resource "aws_cloudwatch_metric_alarm" "alb_4xx_errors" {
  alarm_name          = "App1-ALB-HTTP-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  datapoints_to_alarm = "2"
  evaluation_periods  = "3"
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "120"
  statistic           = "Sum"
  threshold           = "5"
  treat_missing_data  = "missing"
  dimensions = {
    LoadBalancer = module.alb.lb_arn_suffix
  }
  alarm_description = "This metric monitors ALB HTTP 4xx errors and if they are above 100 in specified interval, it is going to send a notification email"
  ok_actions        = [aws_sns_topic.myasg_sns_topic.arn]
  alarm_actions     = [aws_sns_topic.myasg_sns_topic.arn]
}
```

### Stage-01-04: ASG alarm of Cloud Watch
> Alarm will trigger scaling policy when CPU is above 80%
```
resource "aws_autoscaling_policy" "high_cpu" {
  name                   = "high-cpu"
  scaling_adjustment     = 4
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.my_asg.name
}

resource "aws_cloudwatch_metric_alarm" "app1_asg_cwa_cpu" {
  alarm_name          = "App1-ASG-CWA-CPUUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.my_asg.name
  }
  ok_actions = [aws_sns_topic.myasg_sns_topic.arn]
  alarm_actions = [
    aws_autoscaling_policy.high_cpu.arn,
    aws_sns_topic.myasg_sns_topic.arn
  ]
}
```

### Stage-01-05: CIS alarm of Cloud Watch
```
resource "aws_cloudwatch_log_group" "cis_log_group" {
  name = "cis-log-group-${random_pet.this.id}"
}

module "all_cis_alarms" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/cis-alarms"
  version = "2.1.0"
  disabled_controls = ["DisableOrDeleteCMK", "VPCChanges"]
  log_group_name = aws_cloudwatch_log_group.cis_log_group.name
  alarm_actions  = [aws_sns_topic.myasg_sns_topic.arn]
  tags           = local.common_tags
}
```

### Stage-01-06: Synthetic Canary in Cloud Watch
- Create file: sswebsite2\nodejs\node_modules\sswebsite2.js
- Create zip file

```
$ cd sswebsite2
$ zip -r sswebsite2v1.zip nodejs
```

```
resource "aws_synthetics_canary" "sswebsite2" {
  name                 = "sswebsite2"
  artifact_s3_location = "s3://${aws_s3_bucket.cw_canary_bucket.id}/sswebsite2"
  execution_role_arn   = aws_iam_role.cw_canary_iam_role.arn
  handler              = "sswebsite2.handler"
  zip_file             = "sswebsite2/sswebsite2v1.zip"
  runtime_version      = "syn-nodejs-puppeteer-3.1"
  start_canary         = true
  run_config {
    active_tracing     = true
    memory_in_mb       = 960
    timeout_in_seconds = 60
  }
  schedule {
    expression = "rate(1 minute)"
  }
}

resource "aws_cloudwatch_metric_alarm" "synthetics_alarm_app1" {
  alarm_name          = "Synthetics-Alarm-App1"
  comparison_operator = "LessThanThreshold"
  datapoints_to_alarm = "1"
  evaluation_periods  = "1"
  metric_name         = "SuccessPercent"
  namespace           = "CloudWatchSynthetics"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  treat_missing_data  = "breaching"
  dimensions = {
    CanaryName = aws_synthetics_canary.sswebsite2.id
  }
  alarm_description = "Synthetics alarm metric: SuccessPercent  LessThanThreshold 90"
  ok_actions        = [aws_sns_topic.myasg_sns_topic.arn]
  alarm_actions     = [aws_sns_topic.myasg_sns_topic.arn]
}
```

## Stage 02: Execute terraform command
```
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve
```

## Stage 03: Verification and test
> Login to AWS management console
- Confirm SNS Subscription in your email
- Verify EC2 Instances
- Verify Launch Templates (High Level)
- Verify Autoscaling Group (High Level)
- Verify Load Balancer
- Cloud Watch
  - ALB alarm
  - ASG alarm
  - CIS alarm
  - Synthetics
```
# Access and Test
http://cloudwatch.galaxy-aws.top
http://cloudwatch.galaxy-aws.top/app1/index.html
http://cloudwatch.galaxy-aws.top/app1/metadata.html
```

## Stage 04: Clean Up
```
$ terraform destroy -auto-approve

$ rm -rf .terraform*
$ rm -rf terraform.tfstate*
```
