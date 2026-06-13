# Lambda function
data "aws_ssm_parameter" "database_uri" {
  name       = "/${var.app_name}/${var.environment}/database-uri"
  depends_on = [aws_ssm_parameter.database_uri]
}

data "aws_ssm_parameter" "jwt_secret" {
  name       = "/${var.app_name}/${var.environment}/jwt-secret"
  depends_on = [aws_ssm_parameter.jwt_secret]
}

resource "aws_lambda_function" "api" {
  function_name = "${var.app_name}-api-${var.environment}"
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.app_ecr_repo.repository_url}:${var.ecr_image_tag}"
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  architectures = ["arm64"]

  environment {
    variables = {
      GIN_MODE            = "release"
      DATABASE_URI        = data.aws_ssm_parameter.database_uri.value
      DATABASE_NAME       = var.database_name
      JWT_SECRET          = data.aws_ssm_parameter.jwt_secret.value
      JWT_EXPIRATION      = var.jwt_expiration
      S3_BUCKET_NAME      = aws_s3_bucket.video_uploads_bucket.bucket
      S3_REGION           = var.s3_region
      S3_ENDPOINT         = "https://s3.${var.s3_region}.amazonaws.com"
      S3_USE_SSL          = var.s3_use_ssl
      APPLE_APP_BUNDLE_ID = var.apple_app_bundle_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  tags = { Name = "${var.app_name}-api-${var.environment}" }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.app_name}-api-${var.environment}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 3600
  }
  tags = { Name = "${var.app_name}-api-${var.environment}" }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
