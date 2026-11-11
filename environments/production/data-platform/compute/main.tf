# ─────────────────────────────────────────────────────────────────────────────
# production/data-platform/compute — ECS cluster
#
# Apply order: 4 (after iam/ → network/ → data/)
#
# Creates an ECS cluster with Fargate-first capacity. Dev defaults to
# Fargate (no EC2 capacity) and outside-hours shutdown.
#
# ECS services are NOT managed by this module — they'd go in an ecs-service
# module or directly in the app's own deployment pipeline. This layer creates
# the cluster and its baseline observability.
# ─────────────────────────────────────────────────────────────────────────────

module "ecs_cluster" {
  source = "../../../../modules/aws/ecs-cluster"

  environment         = var.environment
  name                = local.cluster_name
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

  high_availability = {
    multi_az = true
  }

  backup = {
    log_retention_days = var.observability.log_retention_days
  }

  observability = {
    alarm_topic_arn    = var.observability.alarm_topic_arn
    log_retention_days = var.observability.log_retention_days
  }

  iam = {
    service_role_arn     = null # Uses the default AWSServiceRoleForECS
    execution_role_arn   = data.aws_ssm_parameter.ecs_task_exec_role_arn.value
    permissions_boundary = null
  }
}
