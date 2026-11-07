output "attachment_id" {
  description = "TGW attachment ID."
  value       = module.tgw_attachment.attachment_id
}

output "attachment_arn" {
  description = "TGW attachment ARN."
  value       = module.tgw_attachment.attachment_arn
}

output "transit_gateway_id" {
  description = "Hub TGW ID."
  value       = module.tgw_attachment.transit_gateway_id
}

output "compliance_controls" {
  description = "Compliance state."
  value       = module.tgw_attachment.compliance_controls
}