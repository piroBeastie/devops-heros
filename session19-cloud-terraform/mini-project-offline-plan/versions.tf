# Same VPC config as 06-terraform-vpc, but the provider skips every call that
# needs real AWS credentials, so init / validate / plan can be run offline and
# show exactly what would be created - without an AWS account and without
# creating anything billable.

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
