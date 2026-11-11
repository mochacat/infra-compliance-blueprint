# ─────────────────────────────────────────────────────────────────────────────
# development/research/data — locals
# ─────────────────────────────────────────────────────────────────────────────

locals {
  base_tags = merge(
    var.default_tags,
    {
      ManagedBy          = "tofu"
      Environment        = var.environment
      Region             = var.region
      CostCenter         = var.cost_controls.cost_center
      Project            = var.cost_controls.project_code
      DataClassification = var.data_classification
      Jurisdiction       = var.data_residency.jurisdiction
    }
  )

  name_prefix = "${var.environment}-${var.app_name}"
}
