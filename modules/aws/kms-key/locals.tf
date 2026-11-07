locals {
  # Deterministic, human-readable key name embedded in the alias so the CMK is
  # discoverable: e.g. "key-prod-phi" or "app-prod-internal".
  key_name = join("-", compact([
    var.cost_controls.project_code != null ? var.cost_controls.project_code : null,
    var.environment,
    var.data_classification,
  ]))

  base_tags = merge(
    var.default_tags,
    {
      ManagedBy          = "tofu"
      Environment        = var.environment
      Region             = var.region # Pillar 4 — High Availability & Region Control (drift/audit)
      CostCenter         = var.cost_controls.cost_center
      Project            = var.cost_controls.project_code
      DataClassification = var.data_classification
      Jurisdiction       = var.data_residency.jurisdiction
    }
  )
}