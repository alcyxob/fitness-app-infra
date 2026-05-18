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

output "api_gateway_url" {
  description = "The URL of the API Gateway HTTP API."
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "lambda_function_name" {
  description = "The name of the Lambda function."
  value       = aws_lambda_function.api.function_name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function."
  value       = aws_lambda_function.api.arn
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group."
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "deployment_info" {
  description = "Summary of deployment information."
  value = {
    environment    = var.environment
    region         = var.aws_region
    app_name       = var.app_name
    api_url        = aws_apigatewayv2_api.api.api_endpoint
    s3_bucket      = aws_s3_bucket.video_uploads_bucket.bucket
    ecr_repository = aws_ecr_repository.app_ecr_repo.repository_url
    log_group      = aws_cloudwatch_log_group.lambda_logs.name
  }
}
