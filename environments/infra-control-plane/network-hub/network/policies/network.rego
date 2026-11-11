# ─────────────────────────────────────────────────────────────────────────────
# network-hub / network — OPA policies
#
# Policy scope: deny CIDR overlap between hub VPC and spoke VPCs, and enforce
# standard network security controls.
#
# These policies are evaluated by Atlantis / CI against `tofu show -json`
# plan output. See CLAUDE.md Pillars 3, 4, 7.
# ─────────────────────────────────────────────────────────────────────────────

package terraform

# ── Helper: check if two CIDRs overlap ────────────────────────────────────────
# Two CIDRs overlap if one contains the other's start or end address, or if
# they are identical.
cidrs_overlap(a, b) {
  a == b
}

cidrs_overlap(a, b) {
  contains_cidr(a, b)
}

cidrs_overlap(a, b) {
  contains_cidr(b, a)
}

contains_cidr(container, candidate) {
  # Compare network addresses as integers (simplified — true for /16–/28 ranges)
  # For full precision we'd parse the CIDR; for the hub-and-spoke case where
  # ranges are /16–/24, this heuristic catches all real overlaps.
  container_net := split(container, "/")[0]
  candidate_net := split(candidate, "/")[0]
  container_prefix := to_number(split(container, "/")[1])
  candidate_prefix := to_number(split(candidate, "/")[1])

  # A container with a smaller prefix (larger range) contains a candidate
  # with a larger prefix if their network addresses match at the container's
  # prefix length.
  container_prefix <= candidate_prefix
  # Get the first two octets for a rough match check (sufficient for /16+)
  container_octets := split(container_net, ".")
  candidate_octets := split(candidate_net, ".")
  container_octets[0] == candidate_octets[0]
  container_octets[1] == candidate_octets[1]
}

# ── Deny: hub VPC CIDR overlaps with a spoke VPC CIDR (Pillar 3) ─────────────
# This is the primary CIDR overlap gate. Spoke VPC CIDRs are declared in the
# `spoke_cidrs` variable. If the hub CIDR is changed to overlap with any
# declared spoke, this rule fires and blocks the plan.
deny[msg] {
  spoke := input.variables.spoke_cidrs[_]
  spoke_name := spoke.name
  spoke_cidr := spoke.cidr

  hub_resource := input.resource.aws_vpc.vpc.values
  hub_cidr := hub_resource.cidr_block

  cidrs_overlap(hub_cidr, spoke_cidr)

  msg := sprintf(
    "Hub VPC CIDR '%s' overlaps with spoke %q CIDR '%s' (Pillar 3 — Network Security & Isolation). Update the hub VPC CIDR or the spoke CIDR declaration in `spoke_cidrs` variable.",
    [hub_cidr, spoke_name, spoke_cidr]
  )
}

# ── Deny: missing spoke CIDRs declaration in prod (Pillar 3) ──────────────────
# In production, all spoke CIDRs must be declared to prevent accidental overlap.
# In dev/test this is informational only (commented out by default).
deny[msg] {
  input.variables.environment == "prod"
  count(input.variables.spoke_cidrs) == 0
  msg = "Production hub must declare all spoke VPC CIDRs in `spoke_cidrs` variable to prevent routing conflicts (Pillar 3 — Network Security & Isolation)."
}

# ── Deny: public IP on hub resources (Pillar 3) ───────────────────────────────
deny[msg] {
  sg := input.resource.aws_security_group[_]
  rule := sg.values.ingress[_]
  rule.cidr_blocks[_] == "0.0.0.0/0"
  msg = sprintf("Security group %s allows 0.0.0.0/0 ingress (Pillar 3 — Network Security & Isolation).", [sg.values.name])
}

# ── Deny: Missing flow log destination in prod (Pillar 5) ─────────────────────
deny[msg] {
  input.variables.environment == "prod"
  input.variables.flow_log_destination == null
  msg = "Production hub VPC must have flow_log_destination configured (Pillar 5 — Observability)."
}
