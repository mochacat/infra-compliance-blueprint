output "vpc_id" {
  description = "Created VPC ID."
  value       = module.workload_vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The VPC's CIDR."
  value       = module.workload_vpc.vpc_cidr_block
}

output "subnet_ids" {
  description = "Private subnet IDs, map of tier-az → id."
  value       = module.workload_vpc.subnet_ids
}

output "default_security_group_id" {
  description = "Deny-all default SG."
  value       = module.workload_vpc.default_security_group_id
}

output "compliance_controls" {
  description = "Compliance state of the VPC."
  value       = module.workload_vpc.compliance_controls
}