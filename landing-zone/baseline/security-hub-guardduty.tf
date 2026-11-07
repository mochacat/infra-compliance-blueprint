# ─────────────────────────────────────────────────────────────────────────────
# GuardDuty + Security Hub — delegated admin to the Security account
#
# GuardDuty: continuous threat detection across all accounts.
# Security Hub: aggregates security + compliance findings into one dashboard.
#
# Both are delegated so the Security account becomes the single pane of glass.
# Bindings at the org level require the management account; findings are
# visible cross-account via the delegation.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_guardduty_organization_admin_account" "guardduty" {
  count = (var.guardduty_delegate && var.security_account_id != null) ? 1 : 0

  admin_account_id = var.security_account_id
}

resource "aws_securityhub_organization_admin_account" "securityhub" {
  count = (var.securityhub_delegate && var.security_account_id != null) ? 1 : 0

  admin_account_id = var.security_account_id

  lifecycle {
    ignore_changes = [admin_account_id]
  }
}

# The management account itself enables the org-aware administrators.
# This is applied in the Security account, so the provider must send these
# resources to that account. See main.tf for the provider wiring.
resource "aws_guardduty_detector" "org" {
  provider = aws.security
  count    = (var.guardduty_delegate && var.security_account_id != null) ? 1 : 0

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  tags                         = merge(var.default_tags, { Name = "org-guardduty" })
}

resource "aws_guardduty_organization_configuration" "org" {
  provider = aws.security
  count    = (var.guardduty_delegate && var.security_account_id != null) ? 1 : 0

  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.org[0].id
}

resource "aws_securityhub_account" "org" {
  provider = aws.security
  count    = (var.securityhub_delegate && var.security_account_id != null) ? 1 : 0

  enable_default_standards = true
}

resource "aws_securityhub_organization_configuration" "org" {
  provider = aws.security
  count    = (var.securityhub_delegate && var.security_account_id != null) ? 1 : 0

  auto_enable           = true
  auto_enable_standards = "DEFAULT"
}