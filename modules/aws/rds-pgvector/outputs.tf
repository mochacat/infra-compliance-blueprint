output "cluster_id" {
  description = "Aurora cluster identifier."
  value       = aws_rds_cluster.this.id
}

output "cluster_arn" {
  description = "Aurora cluster ARN."
  value       = aws_rds_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Writer endpoint (DNS) for the cluster."
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint (DNS) for read replicas."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "proxy_endpoint" {
  description = "RDS Proxy endpoint for connection pooling."
  value       = aws_db_proxy.this.endpoint
}

output "security_group_id" {
  description = "Cluster security group ID."
  value       = aws_security_group.this.id
}

output "engine_mode" {
  description = "Whether the cluster is serverless (dev/test) or provisioned (prod/staging)."
  value       = local.engine_mode
}

output "dr_global_cluster_identifier" {
  description = "Aurora Global Cluster identifier when cross-region DR is enabled, else null."
  value       = var.backup.cross_region_replica ? aws_rds_global_cluster.this[0].id : null
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment             = var.environment
    region                  = var.region
    allowed_regions         = var.allowed_regions
    encryption_at_rest      = var.kms_key_arn != null
    deletion_protection     = var.backup.deletion_protection
    retention_days          = var.backup.retention_days
    multi_az                = var.high_availability.replica_count >= 1
    data_classification     = var.data_classification
    private_network         = var.network.private_only
    engine_mode             = local.engine_mode
    proxy_enabled           = true
    require_tls             = aws_db_proxy.this.require_tls
    cross_region_dr_enabled = var.backup.cross_region_replica
    dr_replica_region       = var.backup.replica_region
  }
}