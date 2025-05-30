
locals {
  cloudtrail_arn = var.org_cloudtrail_enabled ? aws_cloudwatch_log_group.cloudtrail_1day[0].arn : null
  log_group_name  = var.org_cloudtrail_enabled ? split(":", local.cloudtrail_arn)[6] : null
}

resource "aws_cloudwatch_query_definition" "log_management_write_events_only" {
  count = var.org_cloudtrail_enabled ? 1 : 0
  name  = "ManagementWriteEvents"

  log_group_names = [
    local.log_group_name
  ]

  query_string = <<EOF
fields @timestamp, @message, eventName, eventSource
| filter eventSource not in ["logs.amazonaws.com", "cloudtrail.amazonaws.com"]
| sort @timestamp desc
| limit 100
EOF
}

resource "aws_cloudwatch_log_metric_filter" "log_management_write_events_only" {
  count          = var.org_cloudtrail_enabled ? 1 : 0
  name           = "LogManagementWriteEventsFilter"
  log_group_name = local.log_group_name
  pattern        = "{ $.eventSource != \"logs.amazonaws.com\" && $.eventSource != \"cloudtrail.amazonaws.com\" }"
  metric_transformation {
    name      = "LogManagementWriteEventsMetric"
    namespace = "LogManagementWriteEventsNamespace"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "log_management_write_events_only" {
  count = var.org_cloudtrail_enabled ? 1 : 0
  alarm_name          = "ManagementWriteEvents"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = aws_cloudwatch_log_metric_filter.log_management_write_events_only[0].metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.log_management_write_events_only[0].metric_transformation[0].namespace
  period              = "60"  # Check every 60 seconds
  statistic           = "Sum"
  threshold           = "1"   # Trigger when at least one event matches
  alarm_description   = "Alert when a Management Write Event occurs"
  alarm_actions       = [aws_sns_topic.log_management_write_events_only[0].arn]
  treat_missing_data  = "notBreaching" # Mark as OK if there is insufficient data
}

resource "aws_sns_topic" "log_management_write_events_only" {
  count = var.org_cloudtrail_enabled ? 1 : 0
  name  = "LogManagementWriteEvents"
  delivery_policy = jsonencode({
    "http" : {
      "defaultHealthyRetryPolicy" : {
        "minDelayTarget" : 20,
        "maxDelayTarget" : 20,
        "numRetries" : 3,
        "numMaxDelayRetries" : 0,
        "numNoDelayRetries" : 0,
        "numMinDelayRetries" : 0,
        "backoffFunction" : "linear"
      },
      "disableSubscriptionOverrides" : false,
      "defaultThrottlePolicy" : {
        "maxReceivesPerSecond" : 1
      }
    }
  })
}

resource "aws_sns_topic_subscription" "log_management_write_events_only" {
  count     = var.org_cloudtrail_enabled ? 1 : 0
  topic_arn = aws_sns_topic.log_management_write_events_only[0].arn
  protocol  = "email"
  endpoint  = var.org_cloudwatch_alerts_email_addresses
}