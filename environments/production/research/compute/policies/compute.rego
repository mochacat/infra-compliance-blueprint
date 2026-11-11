# ─────────────────────────────────────────────────────────────────────────────
# Compute terraservice — OPA rules
#
# Pillar 3: Tasks must run in private subnets.
# Pillar 4: Multi-AZ required.
# ─────────────────────────────────────────────────────────────────────────────

package terraform.deny.compute

default deny = false

# Reject less than 2 subnets (multi-AZ violation)
deny = "At least 2 subnets required for multi-AZ" {
  subnets = input.terraform_config.variable.app_subnet_ids.value
  count(subnets) < 2
}
