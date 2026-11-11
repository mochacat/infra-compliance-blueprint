# ─────────────────────────────────────────────────────────────────────────────
# development/platform/data — outputs
#
# Compute and AI layers read database connection info from here.
# ─────────────────────────────────────────────────────────────────────────────

output "pgvector_cluster_arn" {
  description = "ARN of the Aurora pgvector cluster."
  value       = module.pgvector.cluster_arn
}

output "pgvector_endpoint" {
  description = "Writer endpoint (DNS) for the Aurora pgvector cluster."
  value       = module.pgvector.cluster_endpoint
}

output "pgvector_reader_endpoint" {
  description = "Reader endpoint (DNS) for read replicas."
  value       = module.pgvector.cluster_reader_endpoint
}

output "pgvector_proxy_endpoint" {
  description = "RDS Proxy endpoint for connection pooling."
  value       = module.pgvector.proxy_endpoint
}

output "pgvector_security_group_id" {
  description = "Security group ID for the RDS cluster."
  value       = module.pgvector.security_group_id
}

output "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection."
  value       = module.opensearch.collection_arn
}

output "opensearch_collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint URL."
  value       = module.opensearch.collection_endpoint
}

output "opensearch_collection_id" {
  description = "OpenSearch Serverless collection ID."
  value       = module.opensearch.collection_id
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation (Pillar 9)."
  value = {
    environment         = var.environment
    data_classification = var.data_classification
    encryption_at_rest  = data.aws_ssm_parameter.kms_key_arn.value != null
    retention_days      = var.backup.retention_days
    deletion_protection = var.backup.deletion_protection
  }
}

# ── SSM parameter publication (cross-layer contract) ─────────────────────────
resource "aws_ssm_parameter" "pgvector_endpoint" {
  name        = "/environments/${var.environment}/${var.business_unit}/pgvector-endpoint"
  description = "Aurora pgvector writer endpoint for ${var.environment}/platform"
  type        = "SecureString"
  value       = module.pgvector.cluster_endpoint
  key_id      = data.aws_ssm_parameter.kms_key_arn.value
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "pgvector_reader_endpoint" {
  name        = "/environments/${var.environment}/${var.business_unit}/pgvector-reader-endpoint"
  description = "Aurora pgvector reader endpoint for ${var.environment}/platform"
  type        = "SecureString"
  value       = module.pgvector.cluster_reader_endpoint
  key_id      = data.aws_ssm_parameter.kms_key_arn.value
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "pgvector_proxy_endpoint" {
  name        = "/environments/${var.environment}/${var.business_unit}/pgvector-proxy-endpoint"
  description = "RDS Proxy endpoint for ${var.environment}/platform"
  type        = "SecureString"
  value       = module.pgvector.proxy_endpoint
  key_id      = data.aws_ssm_parameter.kms_key_arn.value
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "opensearch_collection_endpoint" {
  name        = "/environments/${var.environment}/${var.business_unit}/opensearch-endpoint"
  description = "OpenSearch Serverless collection endpoint for ${var.environment}/platform"
  type        = "SecureString"
  value       = module.opensearch.collection_endpoint
  key_id      = data.aws_ssm_parameter.kms_key_arn.value
  tags        = local.base_tags
}

