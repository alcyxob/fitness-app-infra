resource "aws_sns_topic" "app_alerts" {
  name              = "${var.app_name}-alerts-${var.environment}"
  kms_master_key_id = "alias/aws/sns"

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

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.app_name}-${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Lambda errors > 10 in 5 minutes"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }

  tags = {
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.app_name}-${var.environment}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 5000
  alarm_description   = "Lambda p99 duration > 5 seconds"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }

  tags = {
    Environment = var.environment
    Project     = var.app_name
  }
}
