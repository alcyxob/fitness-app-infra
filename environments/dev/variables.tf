variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-west-1" # Or your preferred region
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
  default     = "latest" # Change this as part of your CI/CD
}

variable "s3_bucket_name_suffix" {
  description = "A suffix to make the S3 bucket name unique."
  type        = string
  default     = "videos" # Will be combined with app_name and env
}

# --- App Runner Configuration ---
variable "app_runner_cpu" {
  description = "CPU for App Runner instance."
  type        = string
  default     = "1 vCPU" # Options: "0.25 vCPU", "0.5 vCPU", "1 vCPU", "2 vCPU", "4 vCPU"
}

variable "app_runner_memory" {
  description = "Memory for App Runner instance."
  type        = string
  default     = "2 GB" # Options: "0.5 GB", "1 GB", "2 GB", "3 GB", ..., "12 GB"
}

variable "app_runner_port" {
  description = "The port your application listens on inside the container."
  type        = number
  default     = 8080
}

# --- Application Environment Variables ---
# These will be passed to your App Runner service
# For sensitive values, use Terraform Cloud variables or AWS Secrets Manager

variable "database_uri" {
  description = "MongoDB connection URI (from MongoDB Atlas or other provider)."
  type        = string
  sensitive   = true # Mark as sensitive
  # No default, must be provided
}

variable "database_name" {
  description = "Name of the database."
  type        = string
  default     = "fitness_app_dev"
}

variable "jwt_secret" {
  description = "Secret key for JWT signing."
  type        = string
  sensitive   = true
  # No default, must be provided
}

variable "jwt_expiration" {
  description = "JWT expiration duration string (e.g., '1h', '60m')."
  type        = string
  default     = "60m"
}

variable "s3_public_endpoint" {
  description = "Publicly accessible S3 endpoint for client-side pre-signed URLs."
  type        = string
  # No default, will be derived or must be provided if different from S3 default.
  # For AWS S3, this is usually not needed as SDK generates correct public URLs.
  # For MinIO, it was http://localhost:9000. For actual S3, it's built into the pre-signed URL.
  # We might not need to pass this explicitly if using AWS S3 with default endpoints.
  # The Go app will construct this based on the bucket and region for AWS S3.
  # This variable was more for local MinIO setup. For AWS S3, the pre-signed URL will be correct.
  # We'll likely remove this env var for the App Runner service if using AWS S3 directly.
  default = "" # Leave empty for now for AWS S3
}

variable "s3_region" {
  description = "The AWS region for the S3 bucket (should match aws_region usually)."
  type        = string
  default     = "eu-west-1" # Match aws_region or specify if different
}

variable "s3_use_ssl" {
  description = "Whether the S3 endpoint uses SSL."
  type        = string # Terraform env vars are strings
  default     = "true" # For AWS S3, always true
}

# --- Custom Domain (Optional) ---
variable "custom_domain_name" {
  description = "Your custom domain name (e.g., api.fitnessapp.example.com)."
  type        = string
  default     = "" # Leave empty if not using a custom domain initially
}

variable "apple_app_bundle_id" {
  description = "The Apple App Bundle ID."
  type        = string
  default     = "com.jutechnik.FitnessClient"
}
