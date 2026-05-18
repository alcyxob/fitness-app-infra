provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.app_name
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "replica"
  region = var.s3_replica_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.app_name
      ManagedBy   = "terraform"
    }
  }
}

locals {
  # Construct names using variables for consistency
  ecr_repo_name         = "${var.app_name}-backend-${var.environment}"
  s3_bucket_actual_name = "${var.app_name}-${var.environment}-${var.s3_bucket_name_suffix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  # S3 bucket names must be globally unique, so adding account ID and region helps.
}

data "aws_caller_identity" "current" {}

// --- ECR Repository to store Docker images ---
resource "aws_ecr_repository" "app_ecr_repo" {
  name                 = local.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = local.ecr_repo_name
    Environment = var.environment
    Project     = var.app_name
  }
}

# ECR Lifecycle Policy to manage image retention
resource "aws_ecr_lifecycle_policy" "app_ecr_lifecycle" {
  repository = aws_ecr_repository.app_ecr_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
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

# KMS key for S3 video uploads encryption
resource "aws_kms_key" "s3_encryption" {
  description         = "KMS key for S3 video uploads encryption"
  enable_key_rotation = true
  tags                = { Name = "${var.app_name}-s3-key-${var.environment}" }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "video_uploads_bucket_encryption" {
  bucket = aws_s3_bucket.video_uploads_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_encryption.arn
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

// Enforce HTTPS-only access to the bucket
resource "aws_s3_bucket_policy" "video_uploads_ssl_only" {
  bucket = aws_s3_bucket.video_uploads_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonSSLRequests"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.video_uploads_bucket.arn,
          "${aws_s3_bucket.video_uploads_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
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

// --- SSM Parameter Store for Secrets ---
// These store secrets encrypted. Next step: update the Go app to read from SSM
// directly using the AWS SDK, then remove DATABASE_URI and JWT_SECRET from
// runtime_environment_variables below.
resource "aws_ssm_parameter" "database_uri" {
  name  = "/${var.app_name}/${var.environment}/database-uri"
  type  = "SecureString"
  value = var.database_uri

  tags = {
    Environment = var.environment
    Project     = var.app_name
  }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/${var.app_name}/${var.environment}/jwt-secret"
  type  = "SecureString"
  value = var.jwt_secret

  tags = {
    Environment = var.environment
    Project     = var.app_name
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# KMS key for CloudWatch Logs encryption
resource "aws_kms_key" "cloudwatch_logs" {
  description         = "KMS key for CloudWatch Logs encryption"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccount"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = { ArnLike = { "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*" } }
      }
    ]
  })
  tags = { Name = "${var.app_name}-cloudwatch-logs-key-${var.environment}" }
}

resource "aws_kms_alias" "cloudwatch_logs" {
  name          = "alias/${var.app_name}-cloudwatch-logs-${var.environment}"
  target_key_id = aws_kms_key.cloudwatch_logs.key_id
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.app_name}-api-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.cloudwatch_logs.arn

  tags = {
    Name        = "${var.app_name}-logs-${var.environment}"
    Environment = var.environment
    Project     = var.app_name
  }
}

# --- S3 Cross-Region Replication (disabled by default for dev) ---
# Enable via enable_s3_replication = true for production environments.

resource "aws_s3_bucket" "video_uploads_replica" {
  count    = var.enable_s3_replication ? 1 : 0
  provider = aws.replica
  bucket   = "${local.s3_bucket_actual_name}-replica"

  tags = {
    Name        = "${local.s3_bucket_actual_name}-replica"
    Environment = var.environment
    Project     = var.app_name
  }
}

resource "aws_s3_bucket_versioning" "video_uploads_replica_versioning" {
  count    = var.enable_s3_replication ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.video_uploads_replica[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "s3_replication_role" {
  count = var.enable_s3_replication ? 1 : 0
  name  = "${var.app_name}-s3-replication-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_replication_policy" {
  count = var.enable_s3_replication ? 1 : 0
  name  = "${var.app_name}-s3-replication-policy-${var.environment}"
  role  = aws_iam_role.s3_replication_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [aws_s3_bucket.video_uploads_bucket.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = ["${aws_s3_bucket.video_uploads_bucket.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = ["${aws_s3_bucket.video_uploads_replica[0].arn}/*"]
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "video_uploads_replication" {
  count  = var.enable_s3_replication ? 1 : 0
  bucket = aws_s3_bucket.video_uploads_bucket.id
  role   = aws_iam_role.s3_replication_role[0].arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.video_uploads_replica[0].arn
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [aws_s3_bucket_versioning.video_uploads_bucket_versioning]
}
