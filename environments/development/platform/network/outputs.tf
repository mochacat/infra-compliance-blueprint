# ─────────────────────────────────────────────────────────────────────────────
# development/platform/network — outputs + SSM publication
#
# Published SSM parameters:
#   /environments/<env>/platform/vpc-id
#   /environments/<env>/platform/app-subnet-ids
#   /environments/<env>/platform/data-subnet-ids
#   /environments/<env>/platform/default-sg-id
#
# Downstream layers (data, compute, ai) read these via aws_ssm_parameter
# data sources, never via terraform_remote_state.
# ─────────────────────────────────────────────────────────────────────────────

# ── Standard outputs ──────────────────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Map of tier-AZ → subnet ID, e.g. { app-us-east-1a = subnet-xxx }"
  value       = module.vpc.subnet_ids
}

output "app_subnet_ids" {
  description = "Subnet IDs for the app tier."
  value       = local.flat_app_subnet_ids
}

output "data_subnet_ids" {
  description = "Subnet IDs for the data tier."
  value       = local.flat_data_subnet_ids
}

output "default_security_group_id" {
  description = "Default (locked-down) security group ID."
  value       = module.vpc.default_security_group_id
}

output "tgw_attachment_id" {
  description = "Transit Gateway attachment ID (if TGW was configured)."
  value       = local.tgw_id != null ? module.tgw_attachment[0].attachment_id : null
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation (Pillar 9)."
  value = {
    environment         = var.environment
    region              = var.region
    data_classification = var.data_classification
    vpc_cidr            = var.vpc_cidr
    subnet_count        = length(local.availability_zones)
    flow_logs           = var.flow_log_destination != null ? "enabled" : "disabled"
    tgw_attached        = local.tgw_id != null
  }
}

# ── SSM parameter publication (cross-layer contract) ─────────────────────────
locals {
  ssm_base_path = "/environments/${var.environment}/${var.business_unit}"

  # Flatten subnet IDs by tier for SSM publication
  flat_app_subnet_ids  = [for k, v in module.vpc.subnet_ids : v if can(regex("^app-", k))]
  flat_data_subnet_ids = [for k, v in module.vpc.subnet_ids : v if can(regex("^data-", k))]
}

resource "aws_ssm_parameter" "vpc_id" {
  name        = "${local.ssm_base_path}/vpc-id"
  description = "VPC ID for ${var.environment}/platform"
  type        = "SecureString"
  value       = module.vpc.vpc_id
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "app_subnet_ids" {
  name        = "/environments/${var.environment}/${var.business_unit}/app-subnet-ids"
  description = "App-tier subnet IDs for ${var.environment}/platform"
  type        = "StringList"
  value       = join(",", local.flat_app_subnet_ids)
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "data_subnet_ids" {
  name        = "/environments/${var.environment}/${var.business_unit}/data-subnet-ids"
  description = "Data-tier subnet IDs for ${var.environment}/platform"
  type        = "StringList"
  value       = join(",", local.flat_data_subnet_ids)
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "default_sg_id" {
  name        = "/environments/${var.environment}/${var.business_unit}/default-sg-id"
  description = "Default security group ID for ${var.environment}/platform"
  type        = "SecureString"
  value       = module.vpc.default_security_group_id
  tags        = local.base_tags
}
