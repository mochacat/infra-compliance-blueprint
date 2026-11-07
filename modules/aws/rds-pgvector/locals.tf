# ─────────────────────────────────────────────────────────────────────────────
# rds-pgvector module — locals
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
      # Snapshot immutability guard (Pillar 6 — Backup, DR & Deletion Protection / Pillar 2 — Access Control & Least Privilege) — copied to snapshots via
      # copy_tags_to_snapshot. IAM policies + OPA use this tag to scope who may
      # delete a snapshot. Regular developers get no DeleteDBSnapshot grant.
      SnapshotGuard = "immutable"
    }
  )
}