# NOTE: API Gateway v2 HTTP APIs don't support WAF directly.
# To use WAF, place CloudFront in front of the API Gateway.
# Keeping the WebACL definition for future CloudFront integration.

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
