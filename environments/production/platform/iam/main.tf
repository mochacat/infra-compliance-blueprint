# ─────────────────────────────────────────────────────────────────────────────
# production/platform/iam — IAM roles for application workloads
#
# Creates the following roles consumed by downstream layers:
#   - ecs-task-exec        → assumed by ECS compute (task execution)
#   - ecs-service          → assumed by ECS service tasks (app code)
#   - sagemaker-execution  → assumed by SageMaker Studio (ai/)
#   - rds-proxy            → assumed by RDS Proxy (data/)
#
# Each role is a dedicated resource — no shared service roles (Pillar 2).
# Downstream layers read ARNs via terraform_remote_state.
# ─────────────────────────────────────────────────────────────────────────────

# ── KMS key (dev convenience) ───────────────────────────────────────────────
# In production, kms_key_arn would be a centrally-managed key from the control
# plane. For dev, we create one so downstream modules have something to use.
resource "aws_kms_key" "this" {
  count                   = var.kms_key_arn == null ? 1 : 0
  description             = "Application encryption key for ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = local.base_tags
}

resource "aws_kms_alias" "this" {
  count         = var.kms_key_arn == null ? 1 : 0
  name          = "alias/${var.environment}-${var.app_name}"
  target_key_id = aws_kms_key.this[0].key_id
}

locals {
  app_kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.this[0].arn
}

# ── ECS task execution role ─────────────────────────────────────────────────
# Used by ECS to pull images, write logs, and fetch secrets on behalf of tasks.
# The compute/ layer configures it as the task execution role.
module "ecs_task_exec_role" {
  source = "../../../../modules/aws/iam-role"
  # In a real clone, use: source = "git::...?ref=vX.Y.Z"

  environment         = var.environment
  name                = "${local.role_prefix}-ecs-task-exec"
  data_classification = var.data_classification
  data_residency      = var.data_residency
  cost_controls       = var.cost_controls
  default_tags        = local.base_tags

  permissions_boundary_arn = var.permissions_boundary_arn

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  policy_statements = [
    {
      sid       = "KMSDecrypt"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [local.app_kms_key_arn]
    },
    {
      sid       = "SecretsManagerRead"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.app_name}-*"]
    },
  ]
}

# ── ECS service (app code) role ─────────────────────────────────────────────
# Used by the application code running in ECS tasks to interact with AWS services.
module "ecs_service_role" {
  source = "../../../../modules/aws/iam-role"

  environment         = var.environment
  name                = "${local.role_prefix}-ecs-service"
  data_classification = var.data_classification
  data_residency      = var.data_residency
  cost_controls       = var.cost_controls
  default_tags        = local.base_tags

  permissions_boundary_arn = var.permissions_boundary_arn

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  policy_statements = [
    {
      sid       = "AOSSReadWrite"
      effect    = "Allow"
      actions   = ["aoss:APIAccessAll"]
      resources = ["*"] # Scoped at the collection access policy, not IAM
    },
    {
      sid       = "S3ReadWrite"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject"]
      resources = ["arn:aws:s3:::${var.app_name}-*", "arn:aws:s3:::${var.app_name}-*/*"]
    },
    {
      sid       = "KMSDecrypt"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [local.app_kms_key_arn]
    },
  ]
}

# ── SageMaker execution role ────────────────────────────────────────────────
# Used by SageMaker Studio domains (ai/ layer). The sagemaker-domain module
# also accepts this as its execution_role_name.
module "sagemaker_execution_role" {
  source = "../../../../modules/aws/iam-role"

  environment         = var.environment
  name                = "${local.role_prefix}-sagemaker-exec"
  data_classification = var.data_classification
  data_residency      = var.data_residency
  cost_controls       = var.cost_controls
  default_tags        = local.base_tags

  permissions_boundary_arn = var.permissions_boundary_arn

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  policy_statements = [
    {
      sid       = "S3DataAccess"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      resources = ["arn:aws:s3:::${var.app_name}-data", "arn:aws:s3:::${var.app_name}-data/*"]
    },
    {
      sid       = "ECRRead"
      effect    = "Allow"
      actions   = ["ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:BatchCheckLayerAvailability"]
      resources = ["*"]
    },
    {
      sid       = "KMSDecrypt"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [local.app_kms_key_arn]
    },
    {
      sid       = "PassRole"
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.role_prefix}-*"]
    },
  ]
}

# ── RDS Proxy role ──────────────────────────────────────────────────────────
# Used by the RDS Proxy in the data/ layer to connect to the Aurora cluster.
module "rds_proxy_role" {
  source = "../../../../modules/aws/iam-role"

  environment         = var.environment
  name                = "${local.role_prefix}-rds-proxy"
  data_classification = var.data_classification
  data_residency      = var.data_residency
  cost_controls       = var.cost_controls
  default_tags        = local.base_tags

  permissions_boundary_arn = var.permissions_boundary_arn

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  policy_statements = [
    {
      sid       = "SecretsManagerRead"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.app_name}-*"]
    },
    {
      sid       = "KMSDecrypt"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [local.app_kms_key_arn]
    },
  ]
}

# ── Current account ID (used in policy ARN construction) ────────────────────
data "aws_caller_identity" "current" {}
