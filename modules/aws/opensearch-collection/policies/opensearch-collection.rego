# ─────────────────────────────────────────────────────────────────────────────
# OPA rules for opensearch-collection module
#
# Evaluated against a `tofu show -json plan.tfplan` at plan time (Atlantis /
# CI layer). Fires BEFORE apply so non-compliant collections never reach AWS.
# # CARRIED FROM GENAI-RUNTIME.md §4:
#   - opensearch_no_kms           fail if kms_key_arn null
#   - opensearch_no_vpc_endpoint  fail if no private VPC endpoint
#   - opensearch_short_retention  fail if retention < 30
# ─────────────────────────────────────────────────────────────────────────────

package terraform

import rego.v1

is_aoss_collection(addr) if contains(addr, "aws_opensearchserverless_collection")
is_aoss_vpce(addr) if contains(addr, "aws_opensearchserverless_vpc_endpoint")
is_aoss_net_policy(addr) if {
	contains(addr, "aws_opensearchserverless_security_policy")
	contains(addr, ".network")
}
is_aoss_enc_policy(addr) if {
	contains(addr, "aws_opensearchserverless_security_policy")
	contains(addr, ".encryption")
}

# The module always provisions an endpoint + encryption policy, so these rules
# guard the policy at the plan level for defense-in-depth (the module has no
# toggle, but this catches drifted/edited configs before apply).

# ── Pillar 1: encryption policy must use a CMK (never AWS-owned) ─────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_aoss_enc_policy(r.address)
	not contains(r.change.after.policy, "KmsARN")
	msg := sprintf("deny: %s — collection encryption policy must reference a KMS CMK (Pillar 1 — Encryption).", [r.address])
}

deny contains msg if {
	r := input.resource_changes[_]
	is_aoss_enc_policy(r.address)
	contains(r.change.after.policy, "AWSOwnedKey\":true")
	msg := sprintf("deny: %s — collection must not use an AWS-owned key (Pillar 1 — Encryption).", [r.address])
}

# ── Pillar 3: network policy must forbid public access ───────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_aoss_net_policy(r.address)
	r.change.after.type == "network"
	contains(r.change.after.policy, "AllowFromPublic\":true")
	msg := sprintf("deny: %s — collection must not allow public access (Pillar 3 — Network Security & Isolation).", [r.address])
}

# ── Pillar 3: every collection must be paired with a private VPC endpoint ────
deny contains msg if {
	r := input.resource_changes[_]
	is_aoss_collection(r.address)
	count(aoss_vpces) < 1
	msg := sprintf("deny: %s — collection requires a private OpenSearch Serverless VPC endpoint (Pillar 3 — Network Security & Isolation).", [r.address])
}

# ── Pillar 6: retention must be ≥ 30 days ────────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_aoss_collection(r.address)
	r.change.after.retention_days < 30
	msg := sprintf("deny: %s — collection retention must be at least 30 days (Pillar 6 — Backup, DR & Deletion Protection).", [r.address])
}

aoss_vpces contains r.address if {
	r := input.resource_changes[_]
	is_aoss_vpce(r.address)
	r.change.after.vpc_id != ""
}