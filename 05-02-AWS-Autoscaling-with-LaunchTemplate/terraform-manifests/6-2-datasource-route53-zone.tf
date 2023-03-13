# get DNS information
data "aws_route53_zone" "mydomain" {
  name = "galaxy-aws.top"
}

# output mydomain zone ID
output "mydomain_zoneid" {
  value = data.aws_route53_zone.mydomain.zone_id
}

# output mydomain name
output "mydomain_name" {
  value = data.aws_route53_zone.mydomain.name
}