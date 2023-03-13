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