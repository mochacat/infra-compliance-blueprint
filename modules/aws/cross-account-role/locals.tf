locals {
  base_tags = merge(var.default_tags, {
    Environment        = var.environment
    DataClassification = var.data_classification
    CostCenter         = var.cost_controls.cost_center
    Project            = var.cost_controls.project_code
    ManagedBy          = "tofu"
  })

  role_name = "cross-account-${var.name}"

  # Build the trust policy — scoped to source accounts + optional conditions.
  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountTrust"
        Effect = "Allow"
        Principal = {
          AWS = var.source_account_arns
        }
        Action = "sts:AssumeRole"
        Condition = var.trust_conditions != null ? {
          (var.trust_conditions.test) = {
            (var.trust_conditions.variable) = var.trust_conditions.values
          }
        } : null
      }
    ]
  })

  # Inline delegation policy from caller's scoped statements.
  inline_policy = length(var.policy_statements) > 0 ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      for st in var.policy_statements : {
        Sid      = st.sid != "" ? st.sid : null
        Effect   = st.effect
        Action   = st.actions
        Resource = st.resources
      }
    ]
  }) : null
}