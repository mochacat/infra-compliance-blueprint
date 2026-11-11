# ─────────────────────────────────────────────────────────────────────────────
# network-hub / network terraservice — locals
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

  hub_name = var.name

  # Resolve availability zones from the subnet config
  availability_zones = distinct(flatten([
    for tier, config in var.subnets : config.availability_zones
  ]))

  # Build the subnet map for the VPC module
  vpc_subnets = {
    for tier, config in var.subnets : tier => {
      availability_zones = config.availability_zones
      cidrs              = config.cidrs
    }
  }

}
