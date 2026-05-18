# Terraform Modules — Planned Structure

This directory will contain reusable Terraform modules extracted from `environments/dev/`.

## Planned Modules

| Module | Description | Resources |
|--------|-------------|-----------|
| `apprunner` | App Runner service, auto-scaling, custom domain | `aws_apprunner_service`, `aws_apprunner_auto_scaling_configuration_version`, `aws_apprunner_custom_domain_association` |
| `s3` | S3 bucket with encryption, versioning, lifecycle, CORS | `aws_s3_bucket`, related bucket configs |
| `iam` | IAM roles and policies for App Runner and S3 access | `aws_iam_role`, `aws_iam_policy`, attachments |
| `monitoring` | CloudWatch alarms, log groups, SNS topics, budgets | `aws_cloudwatch_metric_alarm`, `aws_cloudwatch_log_group`, `aws_sns_topic` |

## Migration Plan

1. Create each module with input variables and outputs
2. Update `environments/dev/` to call modules instead of inline resources
3. Add `environments/prod/` reusing the same modules with different variables
4. Validate with `terraform plan` to ensure no resource recreation
