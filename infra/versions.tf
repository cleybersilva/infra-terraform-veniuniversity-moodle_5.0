# versions.tf

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to use Terraform Cloud/Enterprise for state management
  # backend "remote" {
  #   organization = "your-organization"
  #   workspaces {
  #     name = "moodle-infra"
  #   }
  # }
  
  # Uncomment to use S3 for state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "moodle/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}