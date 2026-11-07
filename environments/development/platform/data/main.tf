# ─────────────────────────────────────────────────────────────────────────────
# development/platform/data — Data layer
#
# Apply order: 3 (after iam/ → network/)
#
# Creates Aurora PostgreSQL + pgvector for hybrid relational/vector storage,
# and OpenSearch Serverless for vector search / RAG document retrieval.
# ─────────────────────────────────────────────────────────────────────────────

# ── Aurora PostgreSQL + pgvector ──────────────────────────────────────────────
# Hybrid vector + relational store for agentic RAG. Dev defaults to Aurora
# Serverless v2 (cheapest) with 1 ACU minimum.
module "pgvector" {
  source = "../../../../modules/aws/rds-pgvector"

  environment         = var.environment
  name                = "${local.name_prefix}-pgvector"
  allowed_regions     = var.allowed_regions
  region              = var.region
  kms_key_arn         = data.aws_ssm_parameter.kms_key_arn.value
  data_classification = var.data_classification
  data_residency      = var.data_residency
  cost_controls       = var.cost_controls
  default_tags        = local.base_tags

  network = {
    vpc_id        = data.aws_ssm_parameter.vpc_id.value
    subnet_ids    = split(",", data.aws_ssm_parameter.data_subnet_ids.value)
    private_only  = true
    allowed_cidrs = []
  }

  observability = {
    alarm_topic_arn     = var.observability.alarm_topic_arn
    log_retention_days  = var.observability.log_retention_days
    detailed_monitoring = false # dev: no detailed monitoring
  }

  backup = {
    retention_days      = var.backup.retention_days
    deletion_protection = var.backup.deletion_protection
    skip_final_snapshot = var.backup.skip_final_snapshot
  }

  high_availability = {
    replica_count = 1 # dev: one reader replica is enough
  }

  pgvector = {
    enabled           = true
    vector_dimensions = 1536
    index_type        = "hnsw"
  }

  iam = {
    permissions_boundary_arn = null
  }

  master_username = var.master_username
  # secret_arn defaults to null — the module uses the RDS-managed secret
  # (manage_master_user_password = true) created and rotated by AWS.
}

# ── OpenSearch Serverless (vector store for RAG) ─────────────────────────────
# Always-private AOSS collection with KMS CMK encryption and standby replicas
# (dev defaults to DISABLED standby to save cost).
module "opensearch" {
  source = "../../../../modules/aws/opensearch-collection"

  environment         = var.environment
  name                = "${local.name_prefix}-vectorstore"
  allowed_regions     = var.allowed_regions
  region              = var.region
  kms_key_arn         = data.aws_ssm_parameter.kms_key_arn.value
  data_classification = var.data_classification
  data_residency      = var.data_residency
  cost_controls       = var.cost_controls
  default_tags        = local.base_tags

  collection = {
    type             = "VECTORSEARCH"
    vector_dimension = 1536
    description      = "Vector store for ${var.environment} ${var.app_name} RAG"
  }

  network = {
    vpc_id             = data.aws_ssm_parameter.vpc_id.value
    subnet_ids         = split(",", data.aws_ssm_parameter.data_subnet_ids.value)
    security_group_ids = [data.aws_ssm_parameter.default_sg_id.value]
  }

  high_availability = {
    standby_replicas = "DISABLED" # dev: no standby replicas to save cost
  }

  backup = {
    retention_days           = var.backup.retention_days
    min_index_retention_days = var.backup.retention_days
  }

  observability = {
    alarm_topic_arn    = var.observability.alarm_topic_arn
    log_retention_days = var.observability.log_retention_days
  }

  iam = {
    principal_arns = [
      data.aws_ssm_parameter.ecs_task_exec_role_arn.value,
      data.aws_ssm_parameter.sagemaker_exec_role_arn.value,
    ]
  }
}
