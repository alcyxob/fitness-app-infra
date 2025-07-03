provider "aws" {
  region = var.aws_region
}

locals {
  # Construct names using variables for consistency
  ecr_repo_name         = "${var.app_name}-backend-${var.environment}"
  s3_bucket_actual_name = "${var.app_name}-${var.environment}-${var.s3_bucket_name_suffix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  # S3 bucket names must be globally unique, so adding account ID and region helps.
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

// --- ECR Repository to store Docker images ---
resource "aws_ecr_repository" "app_ecr_repo" {
  name                 = local.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Lifecycle policy to manage image retention
  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep last 10 images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["v"]
            countType     = "imageCountMoreThan"
            countNumber   = 10
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Delete untagged images older than 1 day"
          selection = {
            tagStatus   = "untagged"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = 1
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }

  tags = {
    Name        = local.ecr_repo_name
    Environment = var.environment
    Project     = var.app_name
  }
}

// --- S3 Bucket for Video Uploads ---
resource "aws_s3_bucket" "video_uploads_bucket" {
  bucket = local.s3_bucket_actual_name

  tags = {
    Name        = local.s3_bucket_actual_name
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_s3_bucket_ownership_controls" "video_uploads_bucket_ownership" {
  bucket = aws_s3_bucket.video_uploads_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Versioning for better data protection
resource "aws_s3_bucket_versioning" "video_uploads_bucket_versioning" {
  bucket = aws_s3_bucket.video_uploads_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "video_uploads_bucket_encryption" {
  bucket = aws_s3_bucket.video_uploads_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle configuration to manage costs
resource "aws_s3_bucket_lifecycle_configuration" "video_uploads_bucket_lifecycle" {
  bucket = aws_s3_bucket.video_uploads_bucket.id

  rule {
    id     = "video_lifecycle"
    status = "Enabled"

    # Move to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete old versions after 30 days
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

// Block all public access by default - presigned URLs will grant temporary access
resource "aws_s3_bucket_public_access_block" "video_uploads_bucket_public_access" {
  bucket = aws_s3_bucket.video_uploads_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// CORS configuration to allow uploads from your web/mobile client's origin
resource "aws_s3_bucket_cors_configuration" "video_uploads_bucket_cors" {
  bucket = aws_s3_bucket.video_uploads_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

// --- AWS App Runner Service ---
resource "aws_apprunner_service" "main_app_service" {
  service_name = "${var.app_name}-service-${var.environment}"

  source_configuration {
    image_repository {
      image_identifier      = "${aws_ecr_repository.app_ecr_repo.repository_url}:${var.ecr_image_tag}"
      image_repository_type = "ECR"
      image_configuration {
        port = var.app_runner_port

        runtime_environment_variables = {
          GIN_MODE            = "release"
          LOG_LEVEL           = var.log_level
          SERVER_ADDRESS      = ":${var.app_runner_port}"
          DATABASE_URI        = var.database_uri
          DATABASE_NAME       = var.database_name
          JWT_SECRET          = var.jwt_secret
          JWT_EXPIRATION      = var.jwt_expiration
          S3_BUCKET_NAME      = aws_s3_bucket.video_uploads_bucket.bucket
          S3_REGION           = var.s3_region
          S3_ENDPOINT         = "https://s3.${var.s3_region}.amazonaws.com"
          S3_PUBLIC_ENDPOINT  = var.s3_public_endpoint != "" ? var.s3_public_endpoint : "https://s3.${var.s3_region}.amazonaws.com"
          S3_USE_SSL          = var.s3_use_ssl
          APPLE_APP_BUNDLE_ID = var.apple_app_bundle_id
        }
      }
    }
    authentication_configuration {
      access_role_arn = aws_iam_role.app_runner_access_role.arn
    }
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.default.arn

  instance_configuration {
    cpu               = var.app_runner_cpu
    memory            = var.app_runner_memory
    instance_role_arn = aws_iam_role.app_runner_instance_role.arn # This enables S3 access
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.app_name}-service-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
}

// --- App Runner Auto Scaling Configuration ---
resource "aws_apprunner_auto_scaling_configuration_version" "default" {
  auto_scaling_configuration_name = "${var.app_name}-autoscaling-${var.environment}"
  max_concurrency                 = var.max_concurrency
  min_size                        = var.min_instances
  max_size                        = var.max_instances

  tags = {
    Name        = "${var.app_name}-autoscaling-${var.environment}"
    Environment = var.environment
  }
}

// --- App Runner Custom Domain Association ---
resource "aws_apprunner_custom_domain_association" "app_runner_domain" {
  count = var.custom_domain_name != "" ? 1 : 0

  domain_name          = "${var.environment}-api.${var.custom_domain_name}"
  service_arn          = aws_apprunner_service.main_app_service.arn
  enable_www_subdomain = false
}

# CloudWatch Log Group for App Runner
resource "aws_cloudwatch_log_group" "app_runner_logs" {
  name              = "/aws/apprunner/${var.app_name}-service-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.app_name}-logs-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
}
