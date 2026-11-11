# ─────────────────────────────────────────────────────────────────────────────
# production/research/ai — GenAI agentic runtime
#
# Apply order: 5 (after iam/ → network/ → data/)
#
# Creates SageMaker Studio as a private AI development environment. Bedrock
# endpoint and guardrail modules are deferred — see tasks.md.
#
# The SageMaker Domain is ALWAYS VpcOnly (no public access) with KMS-encrypted
# storage and a dedicated least-privilege execution role.
# ─────────────────────────────────────────────────────────────────────────────

# ── SageMaker Studio Domain ───────────────────────────────────────────────────
# Private AI development environment. Default Studio instance is ml.t3.medium
# (dev-appropriate). The IAM execution role is defined in the iam/ layer.
module "sagemaker_domain" {
  source = "../../../../modules/aws/sagemaker-domain"

  environment         = var.environment
  name                = local.domain_name
  allowed_regions     = [var.region]
  region              = var.region
  kms_key_arn         = data.aws_ssm_parameter.kms_key_arn.value
  data_classification = var.data_classification
  data_residency      = var.data_residency
  cost_controls       = var.cost_controls
  default_tags        = local.base_tags

  network = {
    vpc_id             = data.aws_ssm_parameter.vpc_id.value
    subnet_ids         = split(",", data.aws_ssm_parameter.app_subnet_ids.value)
    security_group_ids = [data.aws_ssm_parameter.default_sg_id.value]
  }

  iam = {
    execution_role_name      = data.aws_ssm_parameter.sagemaker_exec_role_name.value
    additional_policy_arns   = []
    permissions_boundary_arn = null
  }

  high_availability = {
    multi_az = true
  }

  observability = {
    alarm_topic_arn    = var.observability.alarm_topic_arn
    log_retention_days = var.observability.log_retention_days
  }

  backup = {
    retention_days      = 30
    deletion_protection = true
  }

  auth_mode             = var.auth_mode
  create_default_user   = var.create_default_user
  default_user_name     = var.default_user_name
  sagemaker_bucket_arns = var.sagemaker_bucket_arns
}

# ── Bedrock modules (deferred) ──────────────────────────────────────────────
# bedorkendpoint and bedrockguardrail are marked "LAST — per user" in tasks.md.
# Uncomment and configure when ready:
#
# module "bedrock_guardrail" {
#   source = "../../../modules/aws/bedrock-guardrail"
#   # ...
# }
#
# module "bedrock_endpoint" {
#   source = "../../../modules/aws/bedrock-endpoint"
#   # ...
# }
