# Same S3 resource as the session labs, but the provider is configured to
# skip all the calls that need real AWS credentials. That lets me run
# init / validate / plan offline and see exactly what terraform WOULD create,
# without an AWS account and without creating anything billable.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = "mock-access-key"
  secret_key = "mock-secret-key"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

variable "aws_region" {
  description = "AWS region for the bucket"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}

resource "aws_s3_bucket" "iac_demo" {
  bucket_prefix = "session18-iac-"
  force_destroy = true

  tags = {
    Name        = "Session 18 IaC Demo"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "24bcs10132"
  }
}

output "bucket_id" {
  description = "Name of the bucket terraform would create"
  value       = aws_s3_bucket.iac_demo.id
}

output "bucket_region" {
  description = "Region the bucket is created in"
  value       = var.aws_region
}
