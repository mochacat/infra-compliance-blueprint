# ─────────────────────────────────────────────────────────────────────────────
# OPA rules for the network-hub / transit-gateway terraservice
#
# Evaluated against a `tofu show -json plan.tfplan` at plan time (Atlantis / CI
# layer). Fires BEFORE apply so a misconfigured hub never reaches AWS.
# ─────────────────────────────────────────────────────────────────────────────

package terraform

import rego.v1

is_hub_tg(addr) if contains(addr, "aws_ec2_transit_gateway")
is_ram_share(addr) if contains(addr, "aws_ram_resource_share")

# ── Cross-account discovery is via RAM, not SSM ───────────────────────────────
# An SSM parameter lives in one account and cannot be read from another. For a TG
# spanning accounts, the hub must create the RAM resource share that exposes the
# gateway to the named workload accounts (they accept it and look it up locally).
deny contains msg if {
	r := input.resource_changes[_]
	is_hub_tg(r.address)
	not hub_shares_via_ram
	msg := sprintf("deny: %s — cross-account TG discovery requires a RAM resource share (aws_ram_resource_share) exposing the gateway to the workload accounts (Pillar 3 — Network Security & Isolation).", [r.address])
}

hub_shares_via_ram if {
	some s in input.resource_changes
	is_ram_share(s.address)
}

# ── The hub must declare a classification ▸ PHI requires sovereign_only ───────
deny contains msg if {
	r := input.resource_changes[_]
	is_hub_tg(r.address)
	contains(r.change.after.tags, "DataClassification")
	r.change.after.tags.DataClassification == "phi"
	not r.change.after.tags.Jurisdiction
	msg := sprintf("deny: %s — PHI classification requires a Jurisdiction tag (Pillar 7 — Data Residency & Sovereignty).", [r.address])
}