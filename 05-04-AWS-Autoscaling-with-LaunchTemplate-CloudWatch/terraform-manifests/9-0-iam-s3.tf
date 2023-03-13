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