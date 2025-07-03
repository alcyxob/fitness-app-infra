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

# --- App Runner Configuration ---
variable "app_runner_cpu" {
  description = "CPU for App Runner instance."
  type        = string
  default     = "1 vCPU"
  validation {
    condition = contains([
      "0.25 vCPU", "0.5 vCPU", "1 vCPU", "2 vCPU", "4 vCPU"
    ], var.app_runner_cpu)
    error_message = "CPU must be one of: 0.25 vCPU, 0.5 vCPU, 1 vCPU, 2 vCPU, 4 vCPU."
  }
}

variable "app_runner_memory" {
  description = "Memory for App Runner instance."
  type        = string
  default     = "2 GB"
  validation {
    condition = contains([
      "0.5 GB", "1 GB", "2 GB", "3 GB", "4 GB", "6 GB", "8 GB", "10 GB", "12 GB"
    ], var.app_runner_memory)
    error_message = "Memory must be one of: 0.5 GB, 1 GB, 2 GB, 3 GB, 4 GB, 6 GB, 8 GB, 10 GB, 12 GB."
  }
}

variable "app_runner_port" {
  description = "The port your application listens on inside the container."
  type        = number
  default     = 8080
}

# --- Auto Scaling Configuration ---
variable "min_instances" {
  description = "Minimum number of App Runner instances."
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of App Runner instances."
  type        = number
  default     = 5
}

variable "max_concurrency" {
  description = "Maximum concurrent requests per App Runner instance."
  type        = number
  default     = 100
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

variable "log_level" {
  description = "Application log level."
  type        = string
  default     = "INFO"
  validation {
    condition = contains([
      "DEBUG", "INFO", "WARN", "ERROR"
    ], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARN, ERROR."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 14
}

# --- S3 Configuration ---
variable "s3_public_endpoint" {
  description = "Publicly accessible S3 endpoint for client-side pre-signed URLs."
  type        = string
  default     = ""
}

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
  default     = ["*"] # Restrict this in production
}

# --- Custom Domain (Optional) ---
variable "custom_domain_name" {
  description = "Your custom domain name (e.g., example.com)."
  type        = string
  default     = ""
}

variable "apple_app_bundle_id" {
  description = "The Apple App Bundle ID."
  type        = string
  default     = "com.jutechnik.FitnessClient"
}
