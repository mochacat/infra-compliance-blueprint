output "role_name" {
  description = "Name of the cross-account role."
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "ARN of the cross-account role."
  value       = aws_iam_role.this.arn
}

output "role_unique_id" {
  description = "Unique ID of the cross-account role."
  value       = aws_iam_role.this.unique_id
}

output "trust_policy" {
  description = "The rendered trust policy JSON."
  value       = local.trust_policy
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation (Pillar 9 — Change Management & Policy Enforcement)."
  value = {
    environment              = var.environment
    data_classification      = var.data_classification
    source_account_count     = length(var.source_account_arns)
    permissions_boundary_set = var.permissions_boundary_arn != null
    max_session_duration     = var.max_session_duration
    policy_statement_count   = length(var.policy_statements)
    trust_condition_set      = var.trust_conditions != null
  }
}