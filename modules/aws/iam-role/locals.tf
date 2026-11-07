locals {
  base_tags = merge(var.default_tags, {
    Environment        = var.environment
    DataClassification = var.data_classification
    CostCenter         = var.cost_controls.cost_center
    Project            = var.cost_controls.project_code
    ManagedBy          = "tofu"
  })

  role_name = var.name

  # Inline policy document from the caller's scoped statements.
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