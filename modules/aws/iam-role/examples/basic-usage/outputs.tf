output "role_arn" {
  description = "ARN of the IAM role."
  value       = module.app_role.role_arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = module.app_role.role_name
}

output "compliance_controls" {
  description = "Compliance state for OPA evaluation."
  value       = module.app_role.compliance_controls
}