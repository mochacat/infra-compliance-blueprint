terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider — runs the baseline from the management account.
# Most org-level resources (CloudTrail, Config, audit bucket) use this.
provider "aws" {
  region = var.region

  # Allow plan-only tests without live credentials.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

# Provider used to deploy GuardDuty/Security Hub into the Security account.
# Configured in main.tf because it depends on var.security_account_id.