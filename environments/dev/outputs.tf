output "ecr_repository_url" {
  description = "The URL of the ECR repository."
  value       = aws_ecr_repository.app_ecr_repo.repository_url
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket for video uploads."
  value       = aws_s3_bucket.video_uploads_bucket.bucket
}

output "app_runner_service_url" {
  description = "The default URL of the App Runner service."
  value       = aws_apprunner_service.main_app_service.service_url
}

# output "app_runner_custom_domain_url" {
#   description = "The custom domain URL if configured."
#   value       = var.custom_domain_name != "" ? "https://${var.custom_domain_name}" : "Not configured"
# }
