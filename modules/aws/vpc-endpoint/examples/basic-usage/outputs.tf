output "gateway_endpoint_ids" {
  description = "Gateway endpoint IDs."
  value       = module.vpc_endpoints.gateway_endpoint_ids
}

output "interface_endpoint_ids" {
  description = "Interface endpoint IDs."
  value       = module.vpc_endpoints.interface_endpoint_ids
}

output "interface_endpoint_dns_entries" {
  description = "Interface endpoint DNS entries."
  value       = module.vpc_endpoints.interface_endpoint_dns_entries
}

output "endpoint_count" {
  description = "Total endpoint count."
  value       = module.vpc_endpoints.endpoint_count
}

output "compliance_controls" {
  description = "Compliance state."
  value       = module.vpc_endpoints.compliance_controls
}