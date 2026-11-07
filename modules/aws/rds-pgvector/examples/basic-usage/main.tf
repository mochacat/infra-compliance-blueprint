# Basic usage — a compliant Aurora PostgreSQL + pgvector cluster with RDS Proxy.
#
# This example assumes:
#   - a VPC module produced the VPC + private subnets
#   - a KMS module produced the CMK ARN
#   - a Secrets Manager secret holds the DB credentials
#
# Note: the engine is Aurora Serverless in dev/test (cost) and provisioned in
# prod (performance). Set `environment` accordingly.

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

# Pull the DB credentials from Secrets Manager — never commit a password.
data "aws_secretsmanager_secret" "db" {
  name = var.secret_name
}

data "aws_secretsmanager_secret_version" "db" {
  secret_id = data.aws_secretsmanager_secret.db.id
}

module "pgvector" {
  source = "../../rds-pgvector"

  environment         = var.environment
  name                = "${var.environment}-${var.vpc_name}-rag"
  region              = var.region
  kms_key_arn         = var.kms_key_arn
  secret_arn          = data.aws_secretsmanager_secret.db.arn
  master_password     = data.aws_secretsmanager_secret_version.db.secret_string
  master_username     = var.master_username
  data_classification = var.data_classification

  network = {
    vpc_id        = var.vpc_id
    subnet_ids    = var.data_subnet_ids
    private_only  = true
    allowed_cidrs = var.allowed_cidrs
  }

  high_availability = { replica_count = var.replica_count }
  backup = {
    retention_days      = var.retention_days
    deletion_protection = true
  }

  pgvector = {
    vector_dimensions = var.vector_dimensions
    index_type        = var.index_type
  }

  cost_controls = {
    instance_class = var.instance_class
    cost_center    = var.cost_center
    project_code   = var.project_code
  }
}