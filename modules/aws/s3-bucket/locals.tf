locals {
  bucket_name = var.name

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