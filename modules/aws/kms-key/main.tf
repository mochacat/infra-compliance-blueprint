# ─────────────────────────────────────────────────────────────────────────────
# KMS Key
#
# Creates a customer-managed symmetric key with rotation ALWAYS enabled and a
# least-privilege key policy. The policy only grants:
#   - Key usage   to the explicit `iam_principals` (no "*" principals)
#   - Key admins  to the explicit `admins`
#   - Service principals for the key's declared purpose (append-only)
#
# There is no "encryption disabled" toggle and no rotation-off knob — both
# would violate Pillar 1 / SOC 2 CC6.6.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_kms_key" "this" {
  description              = coalesce(var.kms.description, "${var.environment} ${var.data_classification} data key")
  deletion_window_in_days  = var.kms.deletion_window_days
  enable_key_rotation      = true # Hard-coded ON. Do not expose a toggle.
  is_enabled               = true
  key_usage                = var.kms.usage
  customer_master_key_spec = var.kms.key_spec
  multi_region             = var.kms.multi_region
  policy                   = data.aws_iam_policy_document.key_policy.json
  tags                     = merge(local.base_tags, { Name = local.key_name })

  lifecycle {
    # Cross-variable compliance gates. These cannot live in `variable validation`
    # because OpenTofu blocks a validation from referencing any var but its own.
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }
    precondition {
      condition     = !(var.data_classification == "phi" && var.kms.multi_region)
      error_message = "PHI data must not use a multi-region key (Pillar 7 — Data Residency & Sovereignty)."
    }
    precondition {
      condition     = var.kms.deletion_window_days >= 30
      error_message = "Deletion window must be at least 30 days (Pillar 6 — Backup, DR & Deletion Protection)."
    }
    # Region gate (Pillar 4 — High Availability & Region Control). `region` must be in the approved `allowed_regions`.
    # Lives here (not a variable validation) so it can cross-reference `allowed_regions`.
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }
    # Keys with data under them cannot (and must not) be destroyed casually.
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "this" {
  name          = var.kms.alias_prefix != null && var.kms.alias_prefix != "" ? "alias/${var.kms.alias_prefix}${local.key_name}" : "alias/${local.key_name}"
  target_key_id = aws_kms_key.this.key_id
}

# ─────────────────────────────────────────────────────────────────────────────
# Key policy — least privilege.
#
# We grant access only to the exact principals the caller declares. A grant of
# `kms:*` to `Principal "*"` is rejected by design (Pillar 2 — Access Control & Least Privilege). AWS gives the
# account root implicit admin by default; we keep that but add nothing broader.
# ─────────────────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "key_policy" {
  # checkov:skip=CKV_AWS_111:KMS key policies must grant key-admin actions (CreateGrant, PutKeyPolicy, ScheduleKeyDeletion) to admin principals; Resource "*" is mandatory in KMS policies because the key is the implicit resource.
  # checkov:skip=CKV_AWS_109:KMS key policies necessarily expose permissions-management actions to key administrators; scoped to explicit admin principals only, never "*" principals.
  # checkov:skip=CKV_AWS_356:KMS key policies require Resource "*" (the CMK is the implicit resource); the account root grant is scoped to a single account, not cross-account.
  policy_id = "KMS-${local.key_name}"

  # Account root keeps full control (default AWS behavior) — scoped to account,
  # not to "*" across all accounts.
  statement {
    sid    = "EnableIAMOverAccountRoot"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Explicit admin principals (key administrators).
  dynamic "statement" {
    for_each = length(var.kms.admins) > 0 ? [1] : []
    content {
      sid    = "AllowKeyAdmin"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms.admins
      }
      actions = [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant",
        "kms:PutKeyPolicy",
        "kms:GetKeyPolicy",
        "kms:DescribeKey",
        "kms:EnableKey",
        "kms:DisableKey",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion",
        "kms:TagResource",
        "kms:UntagResource",
      ]
      resources = ["*"]
    }
  }

  # Explicit usage principals (those who encrypt/decrypt with the key).
  dynamic "statement" {
    for_each = length(var.kms.iam_principals) > 0 ? [1] : []
    content {
      sid    = "AllowKeyUse"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.kms.iam_principals
      }
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:DescribeKey",
      ]
      resources = ["*"]
    }
  }
}