# ─────────────────────────────────────────────────────────────────────────────
# Network terraservice — OPA rules
#
# Pillar 3: No public IPs, no 0.0.0.0/0 ingress.
# ─────────────────────────────────────────────────────────────────────────────

package terraform.deny.network

default deny = false

# Reject 0.0.0.0/0 ingress on any security group
deny = "0.0.0.0/0 ingress is forbidden" {
  sg = input.terraform_config.resource.aws_security_group[name]
  some i
  sg.ingress[i].cidr_blocks[_] == "0.0.0.0/0"
}
