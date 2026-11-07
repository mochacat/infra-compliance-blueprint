# ─────────────────────────────────────────────────────────────────────────────
# Cross-Account Role — primary resource
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "this" {
  name                 = local.role_name
  path                 = var.path
  assume_role_policy   = local.trust_policy
  permissions_boundary = var.permissions_boundary_arn
  max_session_duration = var.max_session_duration
  description          = "Cross-account role for ${var.environment} — assumed from ${join(", ", var.source_account_arns)}"
  tags                 = local.base_tags

  lifecycle {
    # Residency gate (Pillar 7 — Data Residency & Sovereignty).
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }

    # Permissions boundary required in prod (Pillar 2 — Access Control & Least Privilege).
    precondition {
      condition     = var.environment != "prod" || var.permissions_boundary_arn != null
      error_message = "Permissions boundary is required in prod (Pillar 2 — Access Control & Least Privilege)."
    }
  }
}

# ── Inline delegation policy (least-privilege, scoped to specific resources).
resource "aws_iam_role_policy" "inline" {
  count  = local.inline_policy != null ? 1 : 0
  name   = "${local.role_name}-delegation"
  role   = aws_iam_role.this.name
  policy = local.inline_policy
}