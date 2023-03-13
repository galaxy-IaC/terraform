# AWS IAM Service Linked role for ASG
resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = local.name

  # some time it's good for a sleep
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# output
output "service_linked_role_arn" {
  value = aws_iam_service_linked_role.autoscaling.arn
}