# ─────────────────────────────────────────────────────────────────────────────
# deploy-role module — locals
#
# Pillar coverage:
#   2  Access:   scoped policy, permissions boundary, no admin access
#   7  Residency: data_classification + data_residency tags and gates
#   9  Change:   environment tagged, compliance_controls output
#  10  FinOps:   CostCenter / Project tags
# ─────────────────────────────────────────────────────────────────────────────

locals {
  base_tags = merge(var.tags, {
    Environment        = var.environment
    DataClassification = var.data_classification
    CostCenter         = var.cost_controls.cost_center
    Project            = var.cost_controls.project_code
    ManagedBy          = "tofu"
  })

  # The deploy-role's scope policy intentionally uses Resource = ["*"] for
  # Describe*/Get/Put actions on state infrastructure (S3/DynamoDB). This is
  # a recognized exception to Pillar 2's no-wildcard rule — the actions
  # themselves are scoped, not a blanket admin grant.
}