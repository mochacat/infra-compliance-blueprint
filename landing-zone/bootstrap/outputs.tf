output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.this.id
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = aws_organizations_organization.this.arn
}

output "root_id" {
  description = "Organization root ID"
  value       = aws_organizations_organization.this.roots[0].id
}

output "management_account_id" {
  description = "Management (root) account ID"
  value       = aws_organizations_organization.this.master_account_id
}

output "ou_ids" {
  description = "Map of OU short names to OU IDs"
  value = {
    infra_control_plane = aws_organizations_organizational_unit.infra_control_plane.id
    infra_network       = aws_organizations_organizational_unit.infra_control_plane_network.id
    production          = aws_organizations_organizational_unit.production.id
    prod_platform       = aws_organizations_organizational_unit.prod_platform.id
    prod_research       = aws_organizations_organizational_unit.prod_research.id
    prod_data           = aws_organizations_organizational_unit.prod_data.id
    preprod             = aws_organizations_organizational_unit.preprod.id
    preprod_platform    = aws_organizations_organizational_unit.preprod_platform.id
    preprod_research    = aws_organizations_organizational_unit.preprod_research.id
    development         = aws_organizations_organizational_unit.development.id
    dev_platform        = aws_organizations_organizational_unit.dev_platform.id
    dev_research        = aws_organizations_organizational_unit.dev_research.id
    sandbox             = aws_organizations_organizational_unit.sandbox.id
  }
}

output "scp_ids" {
  description = "Map of SCP short names to policy IDs"
  value = {
    DenyRootUserActions       = aws_organizations_policy.deny_root_user_actions.id
    RestrictRegions           = aws_organizations_policy.restrict_regions.id
    EnforceEncryptionAtRest   = aws_organizations_policy.enforce_encryption.id
    DenyCloudTrailDisable     = aws_organizations_policy.deny_cloudtrail_disable.id
    DenyPublicAccess          = aws_organizations_policy.deny_public_access.id
    EnforceDeletionProtection = aws_organizations_policy.enforce_deletion_protection.id
    DenySnapshotSkip          = aws_organizations_policy.deny_snapshot_skip.id
    ProtectLogArchiveBucket   = aws_organizations_policy.protect_log_archive.id
  }
}

output "compliance_controls" {
  description = "Compliance state for evaluation"
  value = {
    org_feature_set   = aws_organizations_organization.this.feature_set
    scp_count         = 8
    allowed_regions   = var.allowed_regions
    audit_bucket_name = var.audit_log_bucket_name
    ou_count          = 13
  }
}