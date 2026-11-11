# ─────────────────────────────────────────────────────────────────────────────
# Service Control Policies
#
# Policies are defined as JSON files in policies/ and attached to OUs.
# Each policy is created once and attached to multiple OUs as needed.
# ─────────────────────────────────────────────────────────────────────────────

# ── Policy definitions ──

resource "aws_organizations_policy" "deny_root_user_actions" {
  name        = "DenyRootUserActions"
  description = "Prevents any IAM action by member account root users."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny-root-actions.json")
}

resource "aws_organizations_policy" "restrict_regions" {
  name        = "RestrictRegions"
  description = "Denies actions in non-approved AWS regions."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/restrict-regions.json")
}

resource "aws_organizations_policy" "enforce_encryption" {
  name        = "EnforceEncryptionAtRest"
  description = "Denies creation of unencrypted resources."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/enforce-encryption.json")
}

resource "aws_organizations_policy" "deny_cloudtrail_disable" {
  name        = "DenyCloudTrailDisable"
  description = "Prevents disabling the organization CloudTrail."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny-cloudtrail-disable.json")
}

resource "aws_organizations_policy" "deny_public_access" {
  name        = "DenyPublicAccess"
  description = "Prevents creating publicly-exposed resources."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny-public-access.json")
}

resource "aws_organizations_policy" "enforce_deletion_protection" {
  name        = "EnforceDeletionProtection"
  description = "Prevents disabling deletion protection on stateful resources."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/enforce-deletion-protection.json")
}

resource "aws_organizations_policy" "deny_snapshot_skip" {
  name        = "DenySnapshotSkip"
  description = "Prevents skip_final_snapshot = true in production."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny-snapshot-skip.json")
}

resource "aws_organizations_policy" "protect_log_archive" {
  name        = "ProtectLogArchiveBucket"
  description = "Prevents modification or deletion of the Log Archive bucket."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/protect-log-archive.json")
}

resource "aws_organizations_policy" "enforce_tags" {
  name        = "EnforceMandatoryTags"
  description = "Requires Environment, CostCenter, DataClassification, and ManagedBy tags on every taggable resource (SOC 2 CC6.1 / HIPAA attribution)."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/enforce-tags.json")
}

resource "aws_organizations_policy" "protect_ssm_parameters" {
  name        = "ProtectSSMParameters"
  description = "Restricts SSM parameter write/delete to the Atlantis execution role only. Prevents tampering with the cross-layer SSM contract that downstream layers depend on (Pillar 6)."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/protect-ssm-parameters.json")
}

# ─────────────────────────────────────────────────────────────────────────────
# Attachments
#
# Applied in order: root first, then progressively more specific OUs.
# ─────────────────────────────────────────────────────────────────────────────

# ── Root OU ──
# Every account in the org inherits these.

resource "aws_organizations_policy_attachment" "root_deny_root_user" {
  policy_id = aws_organizations_policy.deny_root_user_actions.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "root_restrict_regions" {
  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "root_enforce_encryption" {
  policy_id = aws_organizations_policy.enforce_encryption.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "root_deny_cloudtrail_disable" {
  policy_id = aws_organizations_policy.deny_cloudtrail_disable.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "root_enforce_tags" {
  policy_id = aws_organizations_policy.enforce_tags.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "root_protect_ssm_parameters" {
  policy_id = aws_organizations_policy.protect_ssm_parameters.id
  target_id = aws_organizations_organization.this.roots[0].id
}

# ── Production OUs ──

resource "aws_organizations_policy_attachment" "prod_deny_public_access" {
  policy_id = aws_organizations_policy.deny_public_access.id
  target_id = aws_organizations_organizational_unit.production.id
}

resource "aws_organizations_policy_attachment" "prod_enforce_deletion_protection" {
  policy_id = aws_organizations_policy.enforce_deletion_protection.id
  target_id = aws_organizations_organizational_unit.production.id
}

resource "aws_organizations_policy_attachment" "prod_deny_snapshot_skip" {
  policy_id = aws_organizations_policy.deny_snapshot_skip.id
  target_id = aws_organizations_organizational_unit.production.id
}

# ── Pre-Production and Development OUs ──
# DenyPublicAccess only — no prod-only controls.

resource "aws_organizations_policy_attachment" "preprod_deny_public_access" {
  policy_id = aws_organizations_policy.deny_public_access.id
  target_id = aws_organizations_organizational_unit.preprod.id
}

resource "aws_organizations_policy_attachment" "dev_deny_public_access" {
  policy_id = aws_organizations_policy.deny_public_access.id
  target_id = aws_organizations_organizational_unit.development.id
}

# ── Infra-Control-Plane OU ──
# ProtectLogArchiveBucket is attached specifically to the Infra-Control-Plane OU.
# In a real deployment you'd scope this tighter (nested OU for Log Archive only),
# but with a single Log Archive account this is sufficient.

resource "aws_organizations_policy_attachment" "infra_protect_log_archive" {
  policy_id = aws_organizations_policy.protect_log_archive.id
  target_id = aws_organizations_organizational_unit.infra_control_plane.id
}