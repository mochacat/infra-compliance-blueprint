# ─────────────────────────────────────────────────────────────────────────────
# IAM Role — primary resource
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "this" {
  name                 = local.role_name
  path                 = var.path
  assume_role_policy   = var.trust_policy
  permissions_boundary = var.permissions_boundary_arn
  max_session_duration = var.max_session_duration
  description          = "IAM role for ${var.environment} ${var.data_classification} workload"
  tags                 = local.base_tags

  lifecycle {
    # Residency gate (Pillar 7 — Data Residency & Sovereignty). Cannot live in a variable validation because
    # OpenTofu forbids a validation from referencing another var.
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

# ── Inline policy (least-privilege, caller-provided scoped statements).
resource "aws_iam_role_policy" "inline" {
  count  = local.inline_policy != null ? 1 : 0
  name   = "${local.role_name}-inline"
  role   = aws_iam_role.this.name
  policy = local.inline_policy
}

# ── Managed policy attachments (use sparingly).
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}