output "cluster_endpoint" {
  description = "Writer endpoint."
  value       = module.pgvector.cluster_endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint."
  value       = module.pgvector.cluster_reader_endpoint
}

output "proxy_endpoint" {
  description = "RDS Proxy endpoint."
  value       = module.pgvector.proxy_endpoint
}

output "engine_mode" {
  description = "serverless or provisioned."
  value       = module.pgvector.engine_mode
}

output "compliance_controls" {
  description = "Compliance state."
  value       = module.pgvector.compliance_controls
}