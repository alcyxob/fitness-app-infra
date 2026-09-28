terraform {
  required_version = ">= 1.3"

  # State bucket and lock table are created by ../../backend-bootstrap.
  backend "s3" {
    bucket         = "fitness-app-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "fitness-app-terraform-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
