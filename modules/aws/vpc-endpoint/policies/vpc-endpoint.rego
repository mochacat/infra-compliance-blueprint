# ─────────────────────────────────────────────────────────────────────────────
# OPA rules for vpc-endpoint module
#
# Evaluated against a `tofu show -json plan.tfplan` at plan time (Atlantis /
# CI layer). Each rule emits a deny message if the plan violates a compliance
# gate. Fires BEFORE apply so non-compliant endpoints never reach AWS.
#
# Rules are self-scoped via resource address prefix so they only apply to this
# module's resources (not the whole plan).
# ─────────────────────────────────────────────────────────────────────────────

package terraform

import rego.v1

# ── Helper: does the given address belong to this module? ────────────────────
is_vpc_endpoint(addr) if contains(addr, "aws_vpc_endpoint")

# ── Pillar 3: no public VPC endpoint type ────────────────────────────────────
# A VPC endpoint must never be of a public type — it must be Gateway or
# Interface (both private). Reject anything else.
deny contains msg if {
	r := input.resource_changes[_]
	is_vpc_endpoint(r.address)
	r.change.after.vpc_endpoint_type == "Service"
	msg := sprintf("deny: %s — VPC endpoint must not be a public service endpoint (Pillar 3 — Network Security & Isolation).", [r.address])
}

# ── Pillar 4 / 3: interface endpoints must span ≥ 2 AZs ─────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_vpc_endpoint(r.address)
	r.change.after.vpc_endpoint_type == "Interface"
	count(r.change.after.subnet_ids) < 2
	msg := sprintf("deny: %s — interface VPC endpoint must span at least 2 AZs (Pillar 4 — High Availability & Region Control).", [r.address])
}

# ── Pillar 4: region must be in allowed_regions ──────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_vpc_endpoint(r.address)
	not region_allowed(r.change.after.allowed_regions, r.change.after.region)
	msg := sprintf("deny: %s — region %s not in allowed_regions (Pillar 4 — High Availability & Region Control).", [r.address, r.change.after.region])
}

region_allowed(allowed, region) if {
	region == allowed[_]
}

# ── Pillar 7: PHI requires sovereign_only ────────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_vpc_endpoint(r.address)
	r.change.after.data_classification == "phi"
	r.change.after.sovereign_only != true
	msg := sprintf("deny: %s — PHI data requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty).", [r.address])
}