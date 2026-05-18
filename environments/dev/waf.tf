resource "aws_wafv2_web_acl" "app_waf" {
  name  = "${var.app_name}-waf-${var.environment}"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.app_name}-rate-limit"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.app_name}-waf"
  }

  tags = { Name = "${var.app_name}-waf-${var.environment}" }
}

resource "aws_wafv2_web_acl_association" "app_waf_association" {
  resource_arn = aws_apprunner_service.main_app_service.arn
  web_acl_arn  = aws_wafv2_web_acl.app_waf.arn
}
