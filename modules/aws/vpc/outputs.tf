output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "VPC ARN."
  value       = aws_vpc.this.arn
}

output "vpc_cidr_block" {
  description = "The VPC's CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "Map of tier-AZ → subnet ID, e.g. { app-us-east-1a = subnet-xxx }"
  value = {
    for k, s in aws_subnet.this : k => s.id
  }
}

output "subnet_arns" {
  description = "Map of tier-AZ → subnet ARN."
  value = {
    for k, s in aws_subnet.this : k => s.arn
  }
}

output "flow_log_id" {
  description = "VPC Flow Log ID (null if destination not configured)."
  value       = var.flow_log_destination != null ? aws_flow_log.vpc[0].id : null
}

output "flow_log_role_arn" {
  description = "IAM role ARN used by VPC Flow Logs for S3 delivery (null if destination not configured)."
  value       = var.flow_log_destination != null ? aws_iam_role.flow_log[0].arn : null
}

output "default_security_group_id" {
  description = "Default security group ID (locked to deny-all)."
  value       = aws_default_security_group.this.id
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment          = var.environment
    region               = var.region
    allowed_regions      = var.allowed_regions
    cidr_block           = var.cidr_block
    reserved_cidrs       = var.reserved_cidrs
    subnet_count         = length(local.subnet_entries)
    subnet_az_count      = length(distinct([for s in local.subnet_entries : s.az]))
    flow_log_destination = var.flow_log_destination != null ? "immutable-s3" : "DISABLED"
    data_classification  = var.data_classification
    default_sg_locked    = true
  }
}
