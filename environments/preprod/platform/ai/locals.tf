# ─────────────────────────────────────────────────────────────────────────────
# preprod/platform/ai — locals
# ─────────────────────────────────────────────────────────────────────────────

locals {
  base_tags = merge(
    var.default_tags,
    {
      ManagedBy          = "tofu"
      Environment        = var.environment
      Region             = var.region
      CostCenter         = var.cost_controls != null ? var.cost_controls.cost_center : "engineering"
      Project            = var.cost_controls != null ? var.cost_controls.project_code : "anestoa"
      DataClassification = var.data_classification
      Jurisdiction       = var.data_residency.jurisdiction
    }
  )

  domain_name = "${var.environment}-${var.app_name}-studio"
}
