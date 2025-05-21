terraform {
  required_version = ">= 1.3" # Use a recent version of Terraform

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a recent version of the AWS provider
    }
    # If you were to manage MongoDB Atlas via Terraform (using the MongoDB Atlas provider)
    # mongodbatlas = {
    #   source  = "mongodb/mongodbatlas"
    #   version = "~> 1.15"
    # }
  }

  # Configure Terraform Cloud backend (if you are using it)
  # cloud {
  #   organization = "your-terraform-cloud-organization-name"
  #   workspaces {
  #     name = "fitness-app-dev" # Or your TFC workspace name
  #   }
  # }
}