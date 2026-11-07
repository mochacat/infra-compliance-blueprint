# ─────────────────────────────────────────────────────────────────────────────
# ecs-cluster module — locals
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # EC2 capacity provider name for the optional ASG-backed capacity.
  # Only meaningful when an ASG is supplied; otherwise the capacity provider
  # is not created at all (Fargate-only).
  ec2_provider_name = var.asg_arn != null ? coalesce(var.capacity_provider_name, "ec2-capacity") : null

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
}