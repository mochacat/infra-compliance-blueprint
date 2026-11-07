output "collection_endpoint" {
  description = "Private vector collection endpoint for RAG queries."
  value       = module.rag_vector_store.collection_endpoint
}

output "collection_id" {
  description = "OpenSearch Serverless collection ID."
  value       = module.rag_vector_store.collection_id
}

output "vpc_endpoint_id" {
  description = "Private AOSS VPC endpoint ID."
  value       = module.rag_vector_store.vpc_endpoint_id
}