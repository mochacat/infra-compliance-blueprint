output "role_arn" {
  description = "ARN of the cross-account role."
  value       = module.shared_log_reader.role_arn
}

output "role_name" {
  description = "Name of the cross-account role."
  value       = module.shared_log_reader.role_name
}

output "trust_policy" {
  description = "The rendered trust policy JSON."
  value       = module.shared_log_reader.trust_policy
}