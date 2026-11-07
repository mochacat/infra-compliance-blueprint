# ─────────────────────────────────────────────────────────────────────────────
# OPA rules for ecs-cluster module
#
# Evaluated against a `tofu show -json plan.tfplan` at plan time (Atlantis /
# CI layer). Fires BEFORE apply so a non-compliant cluster never reaches AWS.
# ─────────────────────────────────────────────────────────────────────────────

package terraform

import rego.v1

is_ecs_cluster(addr) if contains(addr, "aws_ecs_cluster")
is_log_group(addr) if contains(addr, "aws_cloudwatch_log_group")

# ── Pillar 1: cluster task log group must be KMS-encrypted ──────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_log_group(r.address)
	r.change.after.kms_key_id == null
	msg := sprintf("deny: %s — ECS task log group must be encrypted with a CMK (Pillar 1 — Encryption).", [r.address])
}

# ── Pillar 6: task log retention must be ≥ 30 days ──────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_log_group(r.address)
	r.change.after.retention_in_days < 30
	msg := sprintf("deny: %s — task log retention must be at least 30 days (Pillar 6 — Backup, DR & Deletion Protection).", [r.address])
}

# ── Pillar 10: CostCenter tag required ───────────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_ecs_cluster(r.address)
	tags := r.change.after.tags
	not tags.CostCenter
	msg := sprintf("deny: %s — cluster must carry a CostCenter tag (Pillar 10 — FinOps & Cost Controls).", [r.address])
}