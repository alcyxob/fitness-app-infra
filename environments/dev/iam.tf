# IAM Roles and Policies for Fitness App

# --- App Runner Access Role (for ECR access) ---
# This role allows App Runner to pull images from ECR
resource "aws_iam_role" "app_runner_access_role" {
  name = "${var.app_name}-apprunner-access-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-apprunner-access-role-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
}

# ECR Access Policy for App Runner
resource "aws_iam_policy" "app_runner_ecr_access_policy" {
  name        = "${var.app_name}-apprunner-ecr-policy-${var.environment}"
  description = "Policy to allow App Runner to access ECR repository"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-apprunner-ecr-policy-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_iam_role_policy_attachment" "app_runner_access_role_ecr_attachment" {
  role       = aws_iam_role.app_runner_access_role.name
  policy_arn = aws_iam_policy.app_runner_ecr_access_policy.arn
}

# --- App Runner Instance Role (for application runtime permissions) ---
# This role is assumed by the running application containers
resource "aws_iam_role" "app_runner_instance_role" {
  name = "${var.app_name}-apprunner-instance-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-apprunner-instance-role-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
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

  tags = {
    Name        = "${var.app_name}-s3-access-policy-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_iam_role_policy_attachment" "app_runner_instance_role_s3_attachment" {
  role       = aws_iam_role.app_runner_instance_role.name
  policy_arn = aws_iam_policy.app_s3_access_policy.arn
}

# CloudWatch Logs permissions for better observability
resource "aws_iam_policy" "app_cloudwatch_logs_policy" {
  name        = "${var.app_name}-cloudwatch-logs-policy-${var.environment}"
  description = "Policy to allow fitness app to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/apprunner/${var.app_name}-service-${var.environment}*"
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-cloudwatch-logs-policy-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_iam_role_policy_attachment" "app_runner_instance_role_logs_attachment" {
  role       = aws_iam_role.app_runner_instance_role.name
  policy_arn = aws_iam_policy.app_cloudwatch_logs_policy.arn
}

# Optional: Systems Manager Parameter Store access for configuration
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

  tags = {
    Name        = "${var.app_name}-ssm-parameter-policy-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_iam_role_policy_attachment" "app_runner_instance_role_ssm_attachment" {
  role       = aws_iam_role.app_runner_instance_role.name
  policy_arn = aws_iam_policy.app_ssm_parameter_policy.arn
}
