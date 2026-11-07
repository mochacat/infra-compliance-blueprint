# Basic usage — create private VPC endpoints for a workload VPC.
#
# This example creates:
#   - a Gateway endpoint to S3 (free, adds prefix-list route)
#   - Interface endpoints to SSM + STS (private DNS, multi-AZ)
#   - applies a least-privilege endpoint policy

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc_endpoints" {
  source = "../../vpc-endpoint"

  environment         = var.environment
  name                = "${var.environment}-${var.vpc_name}-endpoints"
  region              = var.region
  vpc_id              = var.vpc_id
  data_classification = var.data_classification

  # Gateway endpoint to S3 — free, route tables get a prefix-list route.
  gateway_endpoints = [
    {
      service         = "s3"
      route_table_ids = var.route_table_ids
    },
  ]

  # Interface endpoints for management-plane services — private DNS, multi-AZ.
  interface_endpoints = [
    {
      service             = "ssm"
      subnet_ids          = var.endpoint_subnet_ids
      private_dns_enabled = true
    },
    {
      service             = "sts"
      subnet_ids          = var.endpoint_subnet_ids
      private_dns_enabled = true
    },
    {
      service             = "kms"
      subnet_ids          = var.endpoint_subnet_ids
      private_dns_enabled = true
    },
  ]

  security_group_ids = var.endpoint_security_group_ids

  # Least privilege (Pillar 2 — Access Control & Least Privilege) — restrict the S3 endpoint to a single bucket.
  endpoint_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          var.private_bucket_arn,
          "${var.private_bucket_arn}/*",
        ]
      },
    ]
  }

  cost_controls = {
    cost_center  = var.cost_center
    project_code = var.project_code
  }
}