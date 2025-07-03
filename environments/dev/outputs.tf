output "ecr_repository_url" {
  description = "The URL of the ECR repository."
  value       = aws_ecr_repository.app_ecr_repo.repository_url
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket for video uploads."
  value       = aws_s3_bucket.video_uploads_bucket.bucket
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket for video uploads."
  value       = aws_s3_bucket.video_uploads_bucket.arn
}

output "app_runner_service_url" {
  description = "The default URL of the App Runner service."
  value       = aws_apprunner_service.main_app_service.service_url
}

output "app_runner_service_arn" {
  description = "The ARN of the App Runner service."
  value       = aws_apprunner_service.main_app_service.arn
}

output "app_runner_instance_role_arn" {
  description = "The ARN of the App Runner instance role (for S3 access)."
  value       = aws_iam_role.app_runner_instance_role.arn
}

output "app_runner_access_role_arn" {
  description = "The ARN of the App Runner access role (for ECR access)."
  value       = aws_iam_role.app_runner_access_role.arn
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group."
  value       = aws_cloudwatch_log_group.app_runner_logs.name
}

output "custom_domain_validation_records" {
  description = "DNS validation records for custom domain (if configured)."
  value = var.custom_domain_name != "" ? {
    for record in aws_apprunner_custom_domain_association.app_runner_domain[0].certificate_validation_records :
    record.name => {
      name  = record.name
      type  = record.type
      value = record.value
    }
  } : {}
}

output "deployment_info" {
  description = "Summary of deployment information."
  value = {
    environment     = var.environment
    region          = var.aws_region
    app_name        = var.app_name
    service_url     = aws_apprunner_service.main_app_service.service_url
    s3_bucket       = aws_s3_bucket.video_uploads_bucket.bucket
    ecr_repository  = aws_ecr_repository.app_ecr_repo.repository_url
    log_group       = aws_cloudwatch_log_group.app_runner_logs.name
  }
}
