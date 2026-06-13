# SNS Topic for alarm notifications
resource "aws_sns_topic" "app_alerts" {
  name              = "${var.app_name}-alerts-${var.environment}"
  kms_master_key_id = "alias/aws/sns"
  tags              = { Name = "${var.app_name}-alerts-${var.environment}" }
}

resource "aws_sns_topic_subscription" "email_alert" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.app_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Lambda Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.app_name}-${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda errors > 5 in 10 minutes"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]
  dimensions          = { FunctionName = aws_lambda_function.api.function_name }
  tags                = { Environment = var.environment, Project = var.app_name }
}

# Lambda Duration Alarm (latency)
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.app_name}-${var.environment}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 10000
  alarm_description   = "Lambda avg duration > 10s for 15 minutes"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]
  dimensions          = { FunctionName = aws_lambda_function.api.function_name }
  tags                = { Environment = var.environment, Project = var.app_name }
}

# Lambda Throttles Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.app_name}-${var.environment}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda function throttled"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]
  dimensions          = { FunctionName = aws_lambda_function.api.function_name }
  tags                = { Environment = var.environment, Project = var.app_name }
}

# API Gateway 5xx Alarm
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.app_name}-${var.environment}-api-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "API Gateway 5xx errors > 10 in 10 minutes"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]
  dimensions          = { ApiId = aws_apigatewayv2_api.api.id }
  tags                = { Environment = var.environment, Project = var.app_name }
}
