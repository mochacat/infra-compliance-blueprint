# ─────────────────────────────────────────────────────────────────────────────
# Computed values, naming, and tags for the cloudtrail module.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # Resource naming — single source of truth.
  trail_name     = "${var.name}-trail"
  bucket_name    = var.bucket_name_prefix
  log_group_name = "/aws/cloudtrail/${var.name}"
  role_name      = "${var.iam.cloudwatch_logs_role_name_prefix}CloudTrail_CloudWatchLogs_Role"

  # Base attribution tags. Pillar 10 (FinOps) requires CostCenter/Project;
  # Pillar 7 (residency) tags the data classification + jurisdiction.
  base_tags = merge(
    var.default_tags,
    {
      ManagedBy          = "tofu"
      Environment        = var.environment
      Region             = var.region # Pillar 4 — drift/audit
      CostCenter         = var.cost_controls.cost_center
      Project            = var.cost_controls.project_code
      DataClassification = var.data_classification
      Jurisdiction       = var.data_residency.jurisdiction
    }
  )

  # Object Lock mode. Pillar 8 (Auditability & Immutability): COMPLIANCE by
  # default; GOVERNANCE is an explicit opt-out that callers must request.
  lock_mode = var.audit_lock_mode

  # Single caller-provided CMK used for both the bucket and the log group.
  kms_key_id = var.kms_key_arn
}