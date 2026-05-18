variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-west-1"
}

variable "app_name" {
  description = "A name prefix for resources."
  type        = string
  default     = "fitness-app"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "ecr_image_tag" {
  description = "The Docker image tag to deploy (e.g., 'latest' or a specific version)."
  type        = string
  default     = "latest"
}

variable "s3_bucket_name_suffix" {
  description = "A suffix to make the S3 bucket name unique."
  type        = string
  default     = "videos"
}

# --- Lambda Configuration ---
variable "lambda_memory_size" {
  description = "Memory size for the Lambda function in MB."
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function in seconds."
  type        = number
  default     = 30
}

# --- Application Environment Variables ---
variable "database_uri" {
  description = "MongoDB connection URI (from MongoDB Atlas or other provider)."
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Name of the database."
  type        = string
  default     = "fitness_app_dev"
}

variable "jwt_secret" {
  description = "Secret key for JWT signing (minimum 32 characters)."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "JWT secret must be at least 32 characters long for security."
  }
}

variable "jwt_expiration" {
  description = "JWT expiration duration string (e.g., '1h', '60m')."
  type        = string
  default     = "60m"
}


variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 14
}

# --- S3 Configuration ---
variable "s3_region" {
  description = "The AWS region for the S3 bucket (should match aws_region usually)."
  type        = string
  default     = "eu-west-1"
}

variable "s3_use_ssl" {
  description = "Whether the S3 endpoint uses SSL."
  type        = string
  default     = "true"
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS configuration."
  type        = list(string)
  default     = ["https://dev-api.fitnessapp.jutechnik.com"]

  validation {
    condition     = var.environment == "dev" || !contains(var.cors_allowed_origins, "*")
    error_message = "Wildcard '*' origin is not allowed in non-dev environments."
  }
}

# --- Custom Domain (Optional) ---

variable "apple_app_bundle_id" {
  description = "The Apple App Bundle ID."
  type        = string
  default     = "com.jutechnik.FitnessClient"
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications."
  type        = string
  default     = ""
}

variable "monthly_budget_limit" {
  description = "Monthly AWS budget limit in USD."
  type        = string
  default     = "50"
}

variable "enable_s3_replication" {
  description = "Enable S3 cross-region replication. Overkill for dev; enable for production."
  type        = bool
  default     = false
}

variable "s3_replica_region" {
  description = "Destination region for S3 cross-region replication."
  type        = string
  default     = "eu-central-1"
}
