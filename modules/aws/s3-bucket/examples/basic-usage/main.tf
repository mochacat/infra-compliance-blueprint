# Minimal usage — a compliant application data bucket, encrypted with a caller CMK.
#
# The bucket is private by default, TLS-only, versioned, and tagged for cost +
# classification. Pass `audit_bucket = true` to add Object Lock (COMPLIANCE, 7 years)
# for immutable audit/evidence stores.

module "app_bucket" {
  source = "../.."

  environment         = var.environment
  region              = var.region          # Pillar 4 — High Availability & Region Control (allowed_regions)
  allowed_regions     = var.allowed_regions # Pillar 4 — High Availability & Region Control (approved region list)
  name                = "anestoa-app-data-${var.environment}"
  kms_key_arn         = var.kms_key_arn # Pillar 1 — Encryption (caller-provided CMK)
  data_classification = var.data_classification
  data_residency      = var.data_residency

  # ship access logs to a centralized audit bucket (Pillar 5 — Observability)
  observability = {
    log_bucket_id = var.audit_log_bucket_id
    log_prefix    = "app-data/"
  }

  cost_controls = {
    cost_center  = var.cost_center
    project_code = var.project_code
  }
}

# An immutable, 7-year, COMPLIANCE Object Lock bucket for audit evidence (Pillar 8 — Auditability & Immutability).
module "audit_bucket" {
  source = "../.."

  environment          = var.environment
  region               = var.region          # Pillar 4 — High Availability & Region Control (allowed_regions)
  allowed_regions      = var.allowed_regions # Pillar 4 — High Availability & Region Control (approved region list)
  name                 = "anestoa-audit-${var.environment}"
  kms_key_arn          = var.audit_kms_key_arn
  audit_bucket         = true # enables Object Lock + compliance gates
  audit_lock_mode      = "COMPLIANCE"
  audit_retention_days = 2557 # 7 years, enforced ≥ 2557 in the module
  data_classification  = "internal"
  data_residency       = { jurisdiction = var.jurisdiction }
}