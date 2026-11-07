# ─────────────────────────────────────────────────────────────────────────────
# network-hub / transit-gateway terraservice — locals
# ─────────────────────────────────────────────────────────────────────────────

locals {
  hub_name = "${var.name}-tgw"

  base_tags = merge(
    var.default_tags,
    {
      ManagedBy          = "tofu"
      Environment        = var.environment
      Region             = var.region
      CostCenter         = var.cost_controls != null ? var.cost_controls.cost_center : null
      Project            = var.cost_controls != null ? var.cost_controls.project_code : null
      DataClassification = var.data_classification
      Jurisdiction       = var.data_residency.jurisdiction
    }
  )

  ssm_parameter_name = "/infrastructure/network-hub/transit-gateway/id"
}