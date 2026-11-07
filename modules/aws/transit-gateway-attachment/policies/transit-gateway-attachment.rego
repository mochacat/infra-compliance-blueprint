# ─────────────────────────────────────────────────────────────────────────────
# OPA rules for transit-gateway-attachment module
#
# Evaluated against a `tofu show -json plan.tfplan` at plan time (Atlantis /
# CI layer). Each rule emits a deny message if the plan violates a compliance
# gate. Fires BEFORE apply so non-compliant attachments never reach AWS.
#
# Rules are self-scoped via resource address prefix so they only apply to this
# module's resources (not the whole plan).
# ─────────────────────────────────────────────────────────────────────────────

package terraform

import rego.v1

# ── Helper: does the given address belong to this module? ────────────────────
is_tgw_attachment(addr) if contains(addr, "aws_ec2_transit_gateway_vpc_attachment")

# ── Pillar 4 / 3: attachment must span ≥ 2 AZs ───────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_tgw_attachment(r.address)
	count(r.change.after.subnet_ids) < 2
	msg := sprintf("deny: %s — TGW attachment must span at least 2 AZs (Pillar 4 — High Availability & Region Control).", [r.address])
}

# ── Pillar 7: PHI requires sovereign_only ────────────────────────────────────
deny contains msg if {
	r := input.resource_changes[_]
	is_tgw_attachment(r.address)
	r.change.after.data_classification == "phi"
	r.change.after.sovereign_only != true
	msg := sprintf("deny: %s — PHI data requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty).", [r.address])
}

# ── Pillar 9: production requires centralized inspection enabled ─────────────
# When a TGW attachment exists in an env marked prod and inspection is off,
# flag it. Centralized network inspection is the single audit point for
# cross-VPC traffic required by HIPAA 164.312(a)(1) / SOC 2 CC6.7.
deny contains msg if {
	r := input.resource_changes[_]
	is_tgw_attachment(r.address)
	r.change.after.environment == "prod"
	r.change.after.appliance_mode_support != "enable"
	msg := sprintf("deny: %s — production TGW attachment must enable centralized network inspection (appliance_mode_support='enable') for HIPAA 164.312(a)(1) / SOC 2 CC6.7.", [r.address])
}