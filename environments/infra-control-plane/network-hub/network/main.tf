# ─────────────────────────────────────────────────────────────────────────────
# network-hub / network terraservice — main
#
# Infra-team OWNED control-plane layer. Creates the hub VPC, attaches to the
# shared Transit Gateway, and deploys shared VPC endpoints.
#
# Pillar coverage:
#   3  Network Security & Isolation: hub VPC (private subnets, VPC endpoints)
#   4  HA & Region Control:          multi-AZ, region gated
#   5  Observability:                VPC flow logs to centralized audit bucket
#   7  Data Residency:               classification + PHI-sovereign gate
#  10  FinOps:                       cost allocation tags
# ─────────────────────────────────────────────────────────────────────────────

# ── VPC (the hub itself) ──────────────────────────────────────────────────────
module "vpc" {
  source = "../../../../modules/aws/vpc"

  environment          = var.environment
  name                 = local.hub_name
  cidr_block           = var.vpc_cidr
  reserved_cidrs       = [for s in var.spoke_cidrs : s.cidr] # prevent overlap with spokes
  allowed_regions      = var.allowed_regions
  region               = var.region
  subnets              = local.vpc_subnets
  flow_log_destination = var.flow_log_destination
  data_classification  = var.data_classification
  data_residency       = var.data_residency
  cost_controls        = var.cost_controls
  default_tags         = local.base_tags
}

# ── Transit Gateway attachment (same-account) ────────────────────────────────
# The hub VPC attaches to the same-account Transit Gateway. No RAM needed —
# the TG id is passed directly. The RAM share from transit-gateway/ is only
# for workload (spoke) accounts.
module "tgw_attachment" {
  source = "../../../../modules/aws/transit-gateway-attachment"

  environment            = var.environment
  name                   = "${local.hub_name}-tgw-attach"
  allowed_regions        = var.allowed_regions
  region                 = var.region
  transit_gateway_id     = var.transit_gateway_id
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = [for k, v in module.vpc.subnet_ids : v if can(regex("^tgw-", k))]
  appliance_mode_support = "disable"
  data_classification    = var.data_classification
  data_residency         = var.data_residency
  cost_controls          = var.cost_controls
  default_tags           = local.base_tags
}

# ── Route tables ────────────────────────────────────────────────────────────
# One private route table per subnet tier. The VPC module creates subnets and
# ENIs but not route tables — the caller owns routing.
resource "aws_route_table" "private" {
  for_each = var.subnets

  vpc_id = module.vpc.vpc_id
  tags   = merge(local.base_tags, { Name = "${local.hub_name}-${each.key}", Tier = each.key })
}

# Associate each subnet to its tier's route table
resource "aws_route_table_association" "private" {
  for_each = module.vpc.subnet_ids

  subnet_id      = each.value
  route_table_id = aws_route_table.private[element(split("-", each.key), 0)].id
}

# Default route through TGW for all private subnets
# All spoke traffic reaches the hub via the TGW and routes to endpoints or
# other spokes through the hub.
resource "aws_route" "tgw_default" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id
  depends_on             = [module.tgw_attachment]
}

# ── VPC Endpoints (hub-shared, for hub account services) ────────────────────
# Gateway endpoints (S3, DynamoDB) are free and provide private access without
# NAT gateways. Interface endpoints provide private access via ENIs.
#
# These endpoints serve the hub account's own services (e.g., SSM for session
# manager, ECR for image pulls, CloudWatch for monitoring). Spoke VPCs have
# their own endpoints in their own accounts.
module "endpoints" {
  source = "../../../../modules/aws/vpc-endpoint"

  environment         = var.environment
  name                = local.hub_name
  allowed_regions     = var.allowed_regions
  region              = var.region
  vpc_id              = module.vpc.vpc_id
  data_classification = var.data_classification
  data_residency      = var.data_residency
  cost_controls       = var.cost_controls
  default_tags        = local.base_tags

  # Security group: reuse the VPC's default (locked-down) SG
  security_group_ids = [module.vpc.default_security_group_id]

  # Gateway endpoints — free, always-on for S3 and DynamoDB
  gateway_endpoints = var.enable_gateway_endpoints ? [
    for ep_service in ["s3", "dynamodb"] : {
      service         = ep_service
      route_table_ids = values(aws_route_table.private)[*].id
    }
  ] : []

  # Interface endpoints — scoped to what the hub account needs
  interface_endpoints = [
    for ep in var.interface_endpoints : {
      service    = ep.service
      subnet_ids = [for k, v in module.vpc.subnet_ids : v if can(regex("^${ep.subnet_key}-", k))]
    }
  ]
}

# ── Compliance check blocks (Pillar 3, 4, 7) ──────────────────────────────────
# These provide testable checkable objects for expect_failures. The actual
# enforcement happens in the module preconditions; these mirrors exist so
# tofu test can assert that the gates fire correctly.

check "region_approved" {
  assert {
    condition     = contains(var.allowed_regions, var.region)
    error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
  }
}

check "phi_sovereign" {
  assert {
    condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
    error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
  }
}

# Note: CIDR overlap is enforced by the VPC module's aws_vpc lifecycle
# precondition (via reserved_cidrs). No check block needed here — the
# module rejects overlapping ranges at plan time. See tests/compliance.tftest.hcl.
