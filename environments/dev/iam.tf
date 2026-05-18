# IAM Roles and Policies for Fitness App (Lambda)

# --- Lambda Execution Role ---
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.app_name}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.app_name}-lambda-role-${var.environment}" }
}

# Attach AWS managed policy for basic Lambda execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 Access Policy for the application
resource "aws_iam_policy" "app_s3_access_policy" {
  name        = "${var.app_name}-s3-access-policy-${var.environment}"
  description = "Policy to allow fitness app to access S3 bucket for video uploads"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.video_uploads_bucket.arn,
          "${aws_s3_bucket.video_uploads_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.video_uploads_bucket.arn
      }
    ]
  })

  tags = { Name = "${var.app_name}-s3-access-policy-${var.environment}" }
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.app_s3_access_policy.arn
}

# SSM Parameter Store access for configuration
resource "aws_iam_policy" "app_ssm_parameter_policy" {
  name        = "${var.app_name}-ssm-parameter-policy-${var.environment}"
  description = "Policy to allow fitness app to read SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.app_name}/${var.environment}/*"
        ]
      }
    ]
  })

  tags = { Name = "${var.app_name}-ssm-parameter-policy-${var.environment}" }
}

resource "aws_iam_role_policy_attachment" "lambda_ssm_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.app_ssm_parameter_policy.arn
}
