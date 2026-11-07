output "key_arn" {
  description = "ARN of the created CMK."
  value       = module.app_key.key_arn
}

output "key_id" {
  description = "ID of the created CMK."
  value       = module.app_key.key_id
}

output "alias_arn" {
  description = "Alias ARN pointing at the key."
  value       = module.app_key.alias_arn
}

output "compliance_controls" {
  description = "Compliance state of the key."
  value       = module.app_key.compliance_controls
}