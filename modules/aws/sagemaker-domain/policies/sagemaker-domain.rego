# ─────────────────────────────────────────────────────────────────────────────
# OPA rules for sagemaker-domain module
#
# Evaluated against a `tofu show -json plan.tfplan` at plan time (Atlantis /
# CI layer). Fires BEFORE apply so a non-compliant SageMaker Domain never
# reaches AWS.
# ─────────────────────────────────────────────────────────────────────────────

package terraform

import rego.v1

is_sm_domain(addr) if contains(addr, "aws_sagemaker_domain")
is_sm_role_policy(addr) if contains(addr, "aws_iam_role_policy")

# ── Pillar 3: SageMaker Domain must ALWAYS be VpcOnly ───────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_sm_domain(r.address)
	r.change.after.app_network_access_type != "VpcOnly"
	msg := sprintf("deny: %s — SageMaker Domain must be VpcOnly (Pillar 3 — Network Security & Isolation).", [r.address])
}

# ── Pillar 1: Domain must reference a KMS CMK for encryption at rest ────────
deny contains msg if {
	r := input.resource_changes[_]
	is_sm_domain(r.address)
	not r.change.after.kms_key_id
	msg := sprintf("deny: %s — SageMaker Domain must be encrypted with a KMS CMK (Pillar 1 — Encryption).", [r.address])
}

# ── Pillar 2: no wildcard Resource in the execution-role policy ─────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_sm_role_policy(r.address)
	contains(r.change.after.policy, "\"Resource\": \"*\"")
	msg := sprintf("deny: %s — execution role must not use a wildcard Resource (Pillar 2 — Access Control & Least Privilege).", [r.address])
}

# ── Pillar 10: CostCenter tag required on the domain ──────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_sm_domain(r.address)
	tags := r.change.after.tags
	not tags.CostCenter
	msg := sprintf("deny: %s — CostCenter tag is required (Pillar 10 — FinOps & Cost Controls).", [r.address])
}