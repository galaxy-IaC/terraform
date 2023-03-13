# Target Tracking Scaling Policies
# Define Autoscaling Policies and Associate them to Autoscaling Group
# policy - 1: based on CPU Utilization of EC2 instance
resource "aws_autoscaling_policy" "avg_cpu_policy_greater_than_xx" {
  name = "avg-cpu-policy-greater-than-xx"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = module.autoscaling.autoscaling_group_id
  estimated_instance_warmup = 180
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

# policy - 2: based on ALB Target Requests
resource "aws_autoscaling_policy" "alb_target_requests_greater_than_yy" {
  name        = "alb-target-requests-greater-than-yy"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = module.autoscaling.autoscaling_group_id
  estimated_instance_warmup = 120
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"
    }
    target_value = 10.0
  }
}