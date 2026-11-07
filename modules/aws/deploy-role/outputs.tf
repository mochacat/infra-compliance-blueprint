output "role_arn" {
  description = "ARN of the deploy role."
  value       = aws_iam_role.deploy.arn
}

output "role_name" {
  description = "Name of the deploy role."
  value       = aws_iam_role.deploy.name
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation (Pillar 9 — Change Management & Policy Enforcement)."
  value = {
    environment              = var.environment
    data_classification      = var.data_classification
    permissions_boundary_set = var.permissions_boundary_arn != null
  }
}