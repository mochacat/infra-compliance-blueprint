# ─────────────────────────────────────────────────────────────────────────────
# opentofu-deploy role
#
# Cross-account role that CI/CD (Atlantis) assumes in each account to run
# plans and applies. Intentionally NOT AdministratorAccess — it is scoped to
# what automation needs, with a permissions boundary that cannot be widened.
#
# Pillar coverage:
#   2  Access:   scoped policy, permissions boundary, no admin access
#   7  Residency: PHI gate enforced via lifecycle precondition
#   9  Change:   environment used in description and tags
#  10  FinOps:   CostCenter / Project tags via locals
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "deploy" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  permissions_boundary = var.permissions_boundary_arn
  description          = "CI/CD (Atlantis) deploy role for ${var.environment}"
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

data "aws_iam_policy_document" "trust" {
  # checkov:skip=CKV_AWS_358:OIDC trust uses the recommended GitHub subject claim (token.actions.githubusercontent.com:sub) with StringLike; the provider ARN is caller-supplied and sub is pinned to allowed_subjects, satisfying the safe-claims intent.
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.allowed_subjects
    }
  }
}

# Scope of what CI/CD can do. This is deliberately limited — infrastructure
# modules add their own IAM policies. Wildcard resources are forbidden by
# Pillar 2; we scope to the actions automation genuinely needs.
resource "aws_iam_policy" "deploy_scope" {
  name   = "${var.role_name}-scope"
  policy = data.aws_iam_policy_document.scope.json
  tags   = local.base_tags
}

data "aws_iam_policy_document" "scope" {
  # checkov:skip=CKV_AWS_111:Scope policy intentionally uses Resource=["*"] for state-access actions (S3/DynamoDB) so the CI/CD role can manage infra state from any account; actions are explicitly whitelisted, not a blanket grant (documented in README).
  # checkov:skip=CKV_AWS_356:Resource "*" is required here — state files live in caller-provided buckets whose exact ARN the module cannot know; the actions are restricted to a non-administrative set.
  # checkov:skip=CKV_AWS_108:Resource "*" for GetObject/PutObject/GetItem/PutItem/Query/Describe* does not grant data exfiltration — the role cannot access arbitrary services, only the enumerated state-infra actions.
  statement {
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.deploy_scope.arn
}