# ─────────────────────────────────────────────────────────────────────────────
# network-hub / network terraservice — outputs
#
# Published SSM parameters:
#   /infrastructure/network-hub/vpc-id
#   /infrastructure/network-hub/app-subnet-ids
#   /infrastructure/network-hub/data-subnet-ids
#   /infrastructure/network-hub/default-sg-id
#   /infrastructure/network-hub/vpc-cidr
#
# These are same-account pointers for infra-team tools and audits. Spoke
# network/ layers do NOT read these cross-account — they read their own
# account-local coordinates.
# ─────────────────────────────────────────────────────────────────────────────

# ── Standard outputs ──────────────────────────────────────────────────────────
output "vpc_id" {
  description = "Hub VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "Hub VPC CIDR block."
  value       = var.vpc_cidr
}

output "subnet_ids" {
  description = "Map of tier-AZ → subnet ID, e.g. { app-us-east-1a = subnet-xxx }"
  value       = module.vpc.subnet_ids
}

output "app_subnet_ids" {
  description = "App-tier subnet IDs in the hub VPC."
  value       = local.flat_app_subnet_ids
}

output "data_subnet_ids" {
  description = "Data-tier subnet IDs in the hub VPC."
  value       = local.flat_data_subnet_ids
}

output "default_security_group_id" {
  description = "Default (locked-down) security group ID in the hub VPC."
  value       = module.vpc.default_security_group_id
}

output "tgw_attachment_id" {
  description = "Transit Gateway attachment ID for the hub VPC."
  value       = module.tgw_attachment.attachment_id
}

output "endpoint_ids" {
  description = "Map of endpoint service → endpoint ID for the hub VPC."
  value = merge(
    module.endpoints.gateway_endpoint_ids,
    module.endpoints.interface_endpoint_ids
  )
}

# ── Pillar 9 — Change management / OPA evaluation ────────────────────────────
output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment         = var.environment
    region              = var.region
    data_classification = var.data_classification
    vpc_cidr            = var.vpc_cidr
    subnet_count        = length(local.availability_zones)
    flow_logs           = var.flow_log_destination != null ? "enabled" : "disabled"
    tgw_attached        = var.transit_gateway_id != null
    spoke_count         = length(var.spoke_cidrs)
    gateway_endpoints   = var.enable_gateway_endpoints ? "enabled" : "disabled"
    interface_endpoints = [for ep in var.interface_endpoints : ep.service]
  }
}

# ── SSM parameter publication (same-account infra-team pointer) ───────────────
locals {
  ssm_base_path = "/infrastructure/network-hub"

  flat_app_subnet_ids  = [for k, v in module.vpc.subnet_ids : v if can(regex("^app-", k))]
  flat_data_subnet_ids = [for k, v in module.vpc.subnet_ids : v if can(regex("^data-", k))]
}

resource "aws_ssm_parameter" "vpc_id" {
  name        = "${local.ssm_base_path}/vpc-id"
  description = "Hub VPC ID."
  type        = "SecureString"
  value       = module.vpc.vpc_id
  key_id      = var.kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "vpc_cidr" {
  name        = "${local.ssm_base_path}/vpc-cidr"
  description = "Hub VPC CIDR block."
  type        = "SecureString"
  value       = var.vpc_cidr
  key_id      = var.kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "app_subnet_ids" {
  name        = "${local.ssm_base_path}/app-subnet-ids"
  description = "Hub VPC app-tier subnet IDs."
  type        = "SecureString"
  value       = join(",", local.flat_app_subnet_ids)
  key_id      = var.kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "data_subnet_ids" {
  name        = "${local.ssm_base_path}/data-subnet-ids"
  description = "Hub VPC data-tier subnet IDs."
  type        = "SecureString"
  value       = join(",", local.flat_data_subnet_ids)
  key_id      = var.kms_key_arn
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "default_sg_id" {
  name        = "${local.ssm_base_path}/default-sg-id"
  description = "Hub VPC default security group ID."
  type        = "SecureString"
  value       = module.vpc.default_security_group_id
  key_id      = var.kms_key_arn
  tags        = local.base_tags
}
