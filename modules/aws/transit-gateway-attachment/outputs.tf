output "attachment_id" {
  description = "The TGW attachment ID (tgw-attach-xxx)."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}

output "attachment_arn" {
  description = "The TGW attachment ARN."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.arn
}

output "transit_gateway_id" {
  description = "The hub TGW ID (passthrough for convenience)."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.transit_gateway_id
}

output "vpc_id" {
  description = "The attached VPC ID."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.vpc_id
}

output "appliance_mode" {
  description = "Whether centralized inspection is enabled on this attachment."
  value       = var.appliance_mode_support
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment            = var.environment
    region                 = var.region
    allowed_regions        = var.allowed_regions
    data_classification    = var.data_classification
    appliance_mode_support = var.appliance_mode_support
    subnet_az_count        = length(var.subnet_ids)
    route_table_override   = var.transit_gateway_route_table_id != null ? "custom" : "default"
    centralized_inspection = var.appliance_mode_support == "enable"
  }
}