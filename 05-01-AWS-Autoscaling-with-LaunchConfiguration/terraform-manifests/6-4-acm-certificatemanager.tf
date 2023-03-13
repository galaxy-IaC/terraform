# ACM Module - To create and verify SSL Certificates
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