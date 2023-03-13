# AWS CloudWatch Canary
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

# AWS CloudWatch Metric Alarm for Synthetics Heart Beat Monitor when availability is less than 10 percent
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