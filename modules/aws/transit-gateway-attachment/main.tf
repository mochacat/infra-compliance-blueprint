# ─────────────────────────────────────────────────────────────────────────────
# transit-gateway-attachment module — TGW-VPC attachment (Pillars 3, 4, 7, 10)
#
# Attaches a workload VPC to the central Network Hub Transit Gateway.
# Required by every environment's network/ terraservice.
#
# Pillar coverage:
#   3  Network:      attachment on private TGW subnets, appliance_mode for
#                    centralized inspection (HIPAA 164.312(a)(1) / SOC 2 CC6.7)
#   4  HA:           ≥ 2 AZs required by precondition
#   7  Residency:    data_classification + data_residency tags and gates
#  10  FinOps:       CostCenter / Project tags
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  dns_support                                     = var.dns_support ? "enable" : "disable"
  ipv6_support                                    = var.ipv6_support ? "enable" : "disable"
  appliance_mode_support                          = var.appliance_mode_support
  transit_gateway_default_route_table_association = var.default_route_table_association
  transit_gateway_default_route_table_propagation = var.default_route_table_propagation

  tags = local.base_tags

  lifecycle {
    # HA gate (Pillar 4 — High Availability & Region Control) — must span at least 2 AZs
    precondition {
      condition     = length(var.subnet_ids) >= 2
      error_message = "TGW attachment requires at least 2 subnets in different AZs (Pillar 4 — High Availability & Region Control)."
    }

    # Residency gate (Pillar 7 — Data Residency & Sovereignty) — PHI requires sovereign_only
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }

    # Region gate (Pillar 4 — High Availability & Region Control) — region must be in allowed_regions
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }
  }
}

# ── Route table association override (optional) ──────────────────────────────
# If the caller provides a specific TGW route table ID (e.g. one that routes
# through a firewall appliance), associate this attachment with it instead of
# the default association.
resource "aws_ec2_transit_gateway_route_table_association" "this" {
  count = var.transit_gateway_route_table_id != null ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

# ── Route table propagation (optional) ───────────────────────────────────────
# Propagates routes from the attachment into a specified TGW route table.
# Useful when the workload VPC CIDRs should be reachable from other spokes.
resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  count = var.propagate_to_route_table_id != null ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.propagate_to_route_table_id
}