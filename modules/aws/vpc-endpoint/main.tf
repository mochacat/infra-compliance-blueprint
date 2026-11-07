# ─────────────────────────────────────────────────────────────────────────────
# vpc-endpoint module — private VPC Endpoints (Pillars 3, 4, 7, 10)
#
# Creates both Gateway endpoints (S3, DynamoDB) and Interface endpoints
# (SSM, STS, CloudWatch, etc.) for private connectivity. Keeps all traffic
# within the AWS network — no public internet — which is the transmission
# security control required by HIPAA 164.312(e)(1) and SOC 2 CC6.7.
#
# Pillar coverage:
#   3  Network:      private-only, no public exposure, security-group-scoped
#   4  HA:           interface endpoints span ≥ 2 AZs
#   7  Residency:    data_classification + data_residency tags and gates
#  10  FinOps:       CostCenter / Project tags
# ─────────────────────────────────────────────────────────────────────────────

# ── Gateway endpoints (S3, DynamoDB) ─────────────────────────────────────────
# Gateway endpoints are free, appear as prefix-list routes in the route tables,
# and require a policy + route table association. They do NOT take a security
# group.
resource "aws_vpc_endpoint" "gateway" {
  for_each = { for ep in var.gateway_endpoints : ep.service => ep }

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.value.service}"
  vpc_endpoint_type = "Gateway"

  policy = var.endpoint_policy != null ? jsonencode(var.endpoint_policy) : null

  route_table_ids = each.value.route_table_ids

  tags = merge(local.base_tags, {
    Name = "${var.name}-${each.value.service}"
  })

  lifecycle {
    # Region gate (Pillar 4 — High Availability & Region Control) — region must be in allowed_regions
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }

    # Residency gate (Pillar 7 — Data Residency & Sovereignty) — PHI requires sovereign_only
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }
  }
}

# ── Interface endpoints (SSM, STS, CloudWatch, KMS, etc.) ───────────────────
# Interface endpoints are charged (~$7.20/mo + data processing), take a
# security group, and require subnets in ≥ 2 AZs for HA.
resource "aws_vpc_endpoint" "interface" {
  for_each = { for ep in var.interface_endpoints : ep.service => ep }

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value.service}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = each.value.private_dns_enabled

  subnet_ids         = each.value.subnet_ids
  security_group_ids = var.security_group_ids

  policy = var.endpoint_policy != null ? jsonencode(var.endpoint_policy) : null

  tags = merge(local.base_tags, {
    Name = "${var.name}-${each.value.service}"
  })

  lifecycle {
    # HA gate (Pillar 4 — High Availability & Region Control) — interface endpoints must span ≥ 2 AZs
    precondition {
      condition     = length(each.value.subnet_ids) >= 2
      error_message = "Interface VPC endpoint requires ≥ 2 subnets in different AZs (Pillar 4 — High Availability & Region Control)."
    }

    # Region gate (Pillar 4 — High Availability & Region Control) — region must be in allowed_regions
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }

    # Residency gate (Pillar 7 — Data Residency & Sovereignty) — PHI requires sovereign_only
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }
  }
}