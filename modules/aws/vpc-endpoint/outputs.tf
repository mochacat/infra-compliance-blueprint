output "gateway_endpoint_ids" {
  description = "Map of gateway endpoint service → endpoint ID."
  value = {
    for k, ep in aws_vpc_endpoint.gateway : k => ep.id
  }
}

output "gateway_endpoint_arns" {
  description = "Map of gateway endpoint service → endpoint ARN."
  value = {
    for k, ep in aws_vpc_endpoint.gateway : k => ep.arn
  }
}

output "interface_endpoint_ids" {
  description = "Map of interface endpoint service → endpoint ID."
  value = {
    for k, ep in aws_vpc_endpoint.interface : k => ep.id
  }
}

output "interface_endpoint_dns_entries" {
  description = <<-EOF
    Map of interface endpoint service → DNS entries for private resolution.
    Each entry is `{ dns_name, hosted_zone_id }`.
  EOF
  value = {
    for k, ep in aws_vpc_endpoint.interface : k => ep.dns_entry
  }
}

output "endpoint_count" {
  description = "Total number of VPC endpoints created."
  value       = length(aws_vpc_endpoint.gateway) + length(aws_vpc_endpoint.interface)
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment         = var.environment
    region              = var.region
    allowed_regions     = var.allowed_regions
    data_classification = var.data_classification
    gateway_endpoints   = keys(aws_vpc_endpoint.gateway)
    interface_endpoints = keys(aws_vpc_endpoint.interface)
    endpoint_policy_set = var.endpoint_policy != null
    interface_ha        = alltrue([for ep in var.interface_endpoints : length(ep.subnet_ids) >= 2])
  }
}