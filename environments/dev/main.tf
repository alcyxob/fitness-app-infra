provider "aws" {
  region = var.aws_region
}

locals {
  # Construct names using variables for consistency
  ecr_repo_name         = "${var.app_name}-backend-${var.environment}"
  s3_bucket_actual_name = "${var.app_name}-${var.environment}-${var.s3_bucket_name_suffix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  # S3 bucket names must be globally unique, so adding account ID and region helps.
  # Alternatively, use random_id resource to generate a unique suffix.
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {} # Get current region if needed, or rely on var.aws_region

// --- ECR Repository to store Docker images ---
resource "aws_ecr_repository" "app_ecr_repo" {
  name                 = local.ecr_repo_name
  image_tag_mutability = "MUTABLE" # Or "IMMUTABLE" for stricter versioning

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = local.ecr_repo_name
    Environment = var.environment
    Project     = var.app_name
  }
}

// --- S3 Bucket for Video Uploads ---
resource "aws_s3_bucket" "video_uploads_bucket" {
  bucket = local.s3_bucket_actual_name # Use the locally constructed unique name

  // It's generally recommended to keep buckets private and use pre-signed URLs
  // or CloudFront with Origin Access Identity for access.
  // No public ACLs by default.
  tags = {
    Name        = local.s3_bucket_actual_name
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_s3_bucket_ownership_controls" "video_uploads_bucket_ownership" {
  bucket = aws_s3_bucket.video_uploads_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced" # Recommended for new buckets
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
    allowed_headers = ["*"]                                    # Be more specific in production if possible
    allowed_methods = ["PUT", "POST", "GET", "DELETE", "HEAD"] // GET/HEAD for viewing, PUT/POST for upload
    allowed_origins = ["*"]                                    // IMPORTANT: Restrict this to your frontend's domain(s) in production (e.g., "https://app.yourdomain.com")
    // For local testing with iOS simulator, you might need "http://localhost" or keep "*" temporarily
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

// --- IAM Role for App Runner Instance ---
// This role allows App Runner to pull images from ECR.
// AWS often creates a service-linked role, but explicitly creating one gives more control.
resource "aws_iam_role" "app_runner_instance_role" {
  name = "${var.app_name}-apprunner-instance-role-${var.environment}"

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
    Name        = "${var.app_name}-apprunner-instance-role-${var.environment}"
    Environment = var.environment
  }
}

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
        Resource = "*" // Allow access to all ECR repositories, or restrict to specific ones
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_runner_instance_role_ecr_attachment" {
  role       = aws_iam_role.app_runner_instance_role.name
  policy_arn = aws_iam_policy.app_runner_ecr_access_policy.arn
}

// --- AWS App Runner Service ---
resource "aws_apprunner_service" "main_app_service" {
  service_name = "${var.app_name}-service-${var.environment}"

  source_configuration {
    image_repository {
      image_identifier      = "${aws_ecr_repository.app_ecr_repo.repository_url}:${var.ecr_image_tag}" # e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/fitness-app-backend-dev:latest
      image_repository_type = "ECR"
      image_configuration {
        port = var.app_runner_port # The port your app listens on (e.g., 8080)

        runtime_environment_variables = {
          GIN_MODE           = "release"                 # Or "debug" for dev
          SERVER_ADDRESS     = ":${var.app_runner_port}" # App Runner sets PORT, but GIN_MODE listens on SERVER_ADDRESS
          DATABASE_URI       = var.database_uri
          DATABASE_NAME      = var.database_name
          JWT_SECRET         = var.jwt_secret
          JWT_EXPIRATION     = var.jwt_expiration // Should be like "60m"
          S3_BUCKET_NAME     = aws_s3_bucket.video_uploads_bucket.bucket
          S3_REGION          = var.s3_region                                                                                       // Region of your S3 bucket
          S3_ENDPOINT        = "https://s3.${var.s3_region}.amazonaws.com"                                                         // Standard S3 endpoint for this region
          S3_PUBLIC_ENDPOINT = var.s3_public_endpoint != "" ? var.s3_public_endpoint : "https://s3.${var.s3_region}.amazonaws.com" // Use public endpoint if set, else default
          S3_USE_SSL         = var.s3_use_ssl
          # Add any other environment variables your Go application needs
        }
      }
    }
    authentication_configuration {
      access_role_arn = aws_iam_role.app_runner_instance_role.arn // Role for ECR access
    }
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.default.arn // Use a default auto-scaling config

  instance_configuration {
    cpu    = var.app_runner_cpu
    memory = var.app_runner_memory
    # instance_role_arn = aws_iam_role.app_runner_instance_role.arn # This is for instance profile, ECR access is via access_role_arn
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/api/v1/ping" # Your app's health check endpoint
    interval            = 10             # seconds
    timeout             = 5              # seconds
    healthy_threshold   = 1
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.app_name}-service-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
}

// --- App Runner Auto Scaling Configuration (Default/Basic) ---
resource "aws_apprunner_auto_scaling_configuration_version" "default" {
  auto_scaling_configuration_name = "${var.app_name}-autoscaling-${var.environment}"
  max_concurrency                 = 100 # Default is 100, adjust based on your app's needs
  min_size                        = 1   # Minimum number of instances
  max_size                        = 5   # Maximum number of instances (adjust for cost/load)

  tags = {
    Name        = "${var.app_name}-autoscaling-${var.environment}"
    Environment = var.environment
  }
}

// --- App Runner Custom Domain Association ---
resource "aws_apprunner_custom_domain_association" "app_runner_domain" {
  count = var.custom_domain_name != "" ? 1 : 0

  domain_name          = "${var.environment}-api.${var.custom_domain_name}" # e.g., dev-api.example.com
  service_arn          = aws_apprunner_service.main_app_service.arn
  enable_www_subdomain = false # Set to true if you want www.dev-api.example.com as well

  # You will need to manually create CNAME records in your Route 53 (or other DNS provider)
  # based on the output of this resource (certificate_validation_records).
  # Terraform can output these values for you.
}

// TODO: Custom Domain, ACM Certificate, Route 53 records if var.custom_domain_name is set 
// The above aws_apprunner_custom_domain_association handles the custom domain part.
// You will still need to manually add the CNAME records provided by App Runner to your DNS zone.
