output "collection_id" {
  description = "OpenSearch Serverless collection ID."
  value       = aws_opensearchserverless_collection.this.id
}

output "collection_arn" {
  description = "OpenSearch Serverless collection ARN."
  value       = aws_opensearchserverless_collection.this.arn
}

output "collection_endpoint" {
  description = "OpenSearch endpoint URL for the collection."
  value       = aws_opensearchserverless_collection.this.collection_endpoint
}

output "collection_dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint for the collection."
  value       = aws_opensearchserverless_collection.this.dashboard_endpoint
}

output "vpc_endpoint_id" {
  description = "The private OpenSearch Serverless VPC endpoint ID."
  value       = aws_opensearchserverless_vpc_endpoint.this.id
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment         = var.environment
    region              = var.region
    allowed_regions     = var.allowed_regions
    encryption_at_rest  = var.kms_key_arn != null
    private_network     = true # module ALWAYS provisions a private VPC endpoint
    standby_replicas    = var.high_availability.standby_replicas
    retention_days      = var.backup.retention_days
    data_classification = var.data_classification
    private_endpoint_id = aws_opensearchserverless_vpc_endpoint.this.id
  }
}