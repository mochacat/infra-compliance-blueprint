# ─────────────────────────────────────────────────────────────────────────────
# production/research/network — VPC, TGW attachment, VPC endpoints
#
# Apply order: 2 (after iam/)
# ─────────────────────────────────────────────────────────────────────────────

# ── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../../../modules/aws/vpc"

  environment          = var.environment
  name                 = local.vpc_name
  cidr_block           = var.vpc_cidr
  reserved_cidrs       = var.reserved_cidrs
  allowed_regions      = var.allowed_regions
  region               = var.region
  subnets              = local.vpc_subnets
  flow_log_destination = var.flow_log_destination
  data_classification  = var.data_classification
  data_residency       = var.data_residency
  cost_controls        = var.cost_controls
  default_tags         = local.base_tags
}

# ── Transit Gateway attachment ───────────────────────────────────────────────
# Attaches this VPC to the Network Hub Transit Gateway for cross-VPC routing
# and centralized network inspection.
#
# The hub TG is shared via RAM. If this account has accepted the share, the TG
# is discoverable via data.aws_ec2_transit_gateway. If not, the SSM parameter
# can be used as a same-account pointer.
module "tgw_attachment" {
  source = "../../../../modules/aws/transit-gateway-attachment"
  count  = local.tgw_id != null ? 1 : 0

  environment            = var.environment
  name                   = "${local.vpc_name}-tgw"
  allowed_regions        = var.allowed_regions
  region                 = var.region
  transit_gateway_id     = local.tgw_id
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = [for k, v in module.vpc.subnet_ids : v if can(regex("^tgw-", k))]
  appliance_mode_support = var.appliance_mode_support
  data_classification    = var.data_classification
  data_residency         = var.data_residency
  cost_controls          = var.cost_controls
  default_tags           = local.base_tags
}

# ── Route tables ────────────────────────────────────────────────────────────
# One private route table per subnet tier (app, data, tgw). The VPC module does
# not create route tables — they are the caller's responsibility.
resource "aws_route_table" "private" {
  for_each = var.subnets

  vpc_id = module.vpc.vpc_id
  tags   = merge(local.base_tags, { Name = "${local.vpc_name}-${each.key}", Tier = each.key })
}

# Associate each subnet to its tier's route table
resource "aws_route_table_association" "private" {
  for_each = module.vpc.subnet_ids

  subnet_id      = each.value
  route_table_id = aws_route_table.private[element(split("-", each.key), 0)].id
}

# Default route through TGW for all private subnets (when TGW is attached)
resource "aws_route" "tgw_default" {
  for_each = local.tgw_id != null ? aws_route_table.private : {}

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = local.tgw_id
  depends_on             = [module.tgw_attachment]
}

# ── VPC Endpoints ───────────────────────────────────────────────────────────
# Gateway endpoints (S3, DynamoDB) are free and provide private access to these
# services without NAT gateways. Interface endpoints provide private access via
# ENIs in the subnets.
module "endpoints" {
  source = "../../../../modules/aws/vpc-endpoint"

  environment         = var.environment
  name                = local.vpc_name
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
  # Route through all private route tables so every subnet can reach S3/DynamoDB
  # without a NAT gateway.
  gateway_endpoints = var.enable_gateway_endpoints ? [
    for ep_service in ["s3", "dynamodb"] : {
      service         = ep_service
      route_table_ids = aws_route_table.private[*].id
    }
  ] : []

  # Interface endpoints — scoped to what this account needs
  interface_endpoints = [
    for ep in var.interface_endpoints : {
      service    = ep.service
      subnet_ids = [for k, v in module.vpc.subnet_ids : v if can(regex("^${ep.subnet_key}-", k))]
    }
  ]
}
