# ─────────────────────────────────────────────────────────────────────────────
# network-hub / transit-gateway terraservice — outputs
# ─────────────────────────────────────────────────────────────────────────────

output "transit_gateway_id" {
  description = "ID of the shared Transit Gateway."
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the shared Transit Gateway."
  value       = aws_ec2_transit_gateway.this.arn
}

output "ssm_parameter_name" {
  description = "SSM parameter name publishing the TG id for workload discovery."
  value       = local.ssm_parameter_name
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter publishing the TG id."
  value       = aws_ssm_parameter.transit_gateway_id.arn
}

output "resource_share_arn" {
  description = "ARN of the RAM resource share exposing the TG for cross-account discovery."
  value       = aws_ram_resource_share.this.arn
}

# ── Pillar 9 — Change management / OPA evaluation ────────────────────────────
# Static facts for the eval layer. No computed values so plan-time assertions work.
output "compliance_controls" {
  description = "Compliance state for OPA evaluation."
  value = {
    environment          = var.environment
    region               = var.region
    region_approved      = contains(var.allowed_regions, var.region)
    data_classification  = var.data_classification
    encryption_at_rest   = var.kms_key_arn != null
    participants         = var.participants
    shared_via_ram       = length(var.participants) > 0
    cross_region_replica = false
    multi_az             = false
  }
}