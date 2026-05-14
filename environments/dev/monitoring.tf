resource "aws_sns_topic" "app_alerts" {
  name = "${var.app_name}-alerts-${var.environment}"

  tags = {
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_sns_topic_subscription" "email_alert" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.app_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "app_runner_5xx" {
  alarm_name          = "${var.app_name}-${var.environment}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxStatusResponses"
  namespace           = "AWS/AppRunner"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "App Runner 5xx errors > 10 in 5 minutes"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]

  dimensions = {
    ServiceName = aws_apprunner_service.main_app_service.service_name
  }

  tags = {
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_runner_latency_p99" {
  alarm_name          = "${var.app_name}-${var.environment}-latency-p99"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestLatency"
  namespace           = "AWS/AppRunner"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 5000
  alarm_description   = "App Runner p99 latency > 5 seconds"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]

  dimensions = {
    ServiceName = aws_apprunner_service.main_app_service.service_name
  }

  tags = {
    Environment = var.environment
    Project     = var.app_name
  }
}
