# ─────────────────────────────────────────────────────────────────────────────
# OPA rules for the cloudtrail module.
#
# Evaluated against a `tofu show -json plan.tfplan` at plan time (Atlantis /
# CI layer). Fires BEFORE apply so a non-compliant / drifted audit trail never
# reaches AWS.
# ─────────────────────────────────────────────────────────────────────────────

package terraform

import rego.v1

# The module is always multi-region + log-file-validated by construction, so
# these rules guard against drift/edited configs (defense-in-depth). The
# platform CI layer is where per-environment strictness is applied.

# ── Pillar 7/8: CloudTrail must be multi-region with log file validation ─────
deny contains msg if {
	r := input.resource_changes[_]
	r.type == "aws_cloudtrail"
	r.change.after.is_multi_region_trail == false
	msg := sprintf("deny: %s — CloudTrail must be multi-region (Pillar 8 — Auditability & Immutability).", [r.address])
}

deny contains msg if {
	r := input.resource_changes[_]
	r.type == "aws_cloudtrail"
	r.change.after.enable_log_file_validation == false
	msg := sprintf("deny: %s — CloudTrail must enable log file validation (Pillar 8 — Auditability & Immutability).", [r.address])
}

# ── Pillar 8: audit bucket must be Object-Locked with versioning ─────────────
deny contains msg if {
	r := input.resource_changes[_]
	r.type == "aws_s3_bucket"
	r.change.after.object_lock_enabled == false
	msg := sprintf("deny: %s — audit bucket must have Object Lock (Pillar 8 — Auditability & Immutability).", [r.address])
}

# ── Pillar 1: bucket must be KMS-encrypted ───────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	contains(r.address, "aws_s3_bucket_server_side_encryption_configuration")
	after := r.change.after.rule[_]
	enc := after.apply_server_side_encryption_by_default
	enc.sse_algorithm == "AES256"
	msg := sprintf("deny: %s — audit bucket must use KMS, not SSE-S3 (Pillar 1 — Encryption).", [r.address])
}

# ── Pillar 10: cost tag required ─────────────────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	r.type == "aws_cloudtrail"
	ts := r.change.after.tags
	not ts["CostCenter"]
	msg := sprintf("deny: %s — missing CostCenter tag (Pillar 10 — FinOps & Cost Controls).", [r.address])
}

# ── Pillar 1: bucket policy must deny non-SecureTransport ────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	contains(r.address, "aws_s3_bucket_policy")
	not contains(r.change.after.policy, "aws:SecureTransport")
	msg := sprintf("deny: %s — bucket policy must enforce SecureTransport (Pillar 1 — Encryption at Rest and In Transit).", [r.address])
}