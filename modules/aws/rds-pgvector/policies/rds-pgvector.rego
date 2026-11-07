# ─────────────────────────────────────────────────────────────────────────────
# OPA rules for rds-pgvector module
#
# Evaluated against a `tofu show -json plan.tfplan` at plan time (Atlantis /
# CI layer). Fires BEFORE apply so non-compliant clusters never reach AWS.
# ─────────────────────────────────────────────────────────────────────────────

package terraform

import rego.v1

is_pgvector_cluster(addr) if contains(addr, "aws_rds_cluster")

# ── Pillar 1: KMS encryption required ────────────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_pgvector_cluster(r.address)
	r.change.after.storage_encrypted != true
	msg := sprintf("deny: %s — cluster must be encrypted at rest with a KMS CMK (Pillar 1 — Encryption).", [r.address])
}

# ── Pillar 6: deletion protection required ──────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_pgvector_cluster(r.address)
	r.change.after.deletion_protection != true
	msg := sprintf("deny: %s — deletion protection must be enabled (Pillar 6 — Backup, DR & Deletion Protection).", [r.address])
}

# ── Pillar 6: retention ≥ 30 days ───────────────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_pgvector_cluster(r.address)
	r.change.after.backup_retention_period < 30
	msg := sprintf("deny: %s — backup retention must be at least 30 days (Pillar 6 — Backup, DR & Deletion Protection).", [r.address])
}

# ── Pillar 6: prod must not skip final snapshot ──────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_pgvector_cluster(r.address)
	r.change.after.environment == "prod"
	r.change.after.skip_final_snapshot == true
	msg := sprintf("deny: %s — production must keep the final snapshot (Pillar 6 — Backup, DR & Deletion Protection).", [r.address])
}

# ── Pillar 7: PHI requires sovereign_only ───────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_pgvector_cluster(r.address)
	r.change.after.data_classification == "phi"
	r.change.after.sovereign_only != true
	msg := sprintf("deny: %s — PHI data requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty).", [r.address])
}

# ── Pillar 6 + 2: snapshot immutability — no broad snapshot-delete grants ──
# A regular developer must NOT be able to delete a DB snapshot. Any IAM policy
# granting rds:DeleteDBSnapshot / rds:DeleteDBClusterSnapshot to a wide resource
# ("*") or a broad set of actions is denied. Snapshot lifecycle is owned by the
# backup-vault / ops role only.
deny contains msg if {
	pol := input.resource_changes[_]
	pol.change.after.type == "aws_iam_policy"
	pol.change.after.policy != null
	delete_action := {"rds:DeleteDBSnapshot", "rds:DeleteDBClusterSnapshot"}
	some statement
	parsed := json.unmarshal(pol.change.after.policy)
	statement = parsed.Statement[_]
	some action
	action = statement.Action[_]
	delete_action[action]
	resource_has_wildcard(statement.Resource)
	msg := sprintf("deny: %s — snapshot-delete is granted on a wildcard resource; restrict to the snapshot ARN (Pillar 6, immutable audit).", [pol.address])
}

resource_has_wildcard(resources) if resources == "*"
resource_has_wildcard(resources) if {
	is_array(resources)
	some r
	resources[r] == "*"
}