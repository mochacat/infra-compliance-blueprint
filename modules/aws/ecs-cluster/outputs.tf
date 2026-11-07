output "cluster_id" {
  description = "The ECS cluster ID."
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "The ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "The ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "task_log_group_name" {
  description = "The CloudWatch log group used for task logs."
  value       = aws_cloudwatch_log_group.tasks.name
}

output "task_log_group_arn" {
  description = "The CloudWatch log group ARN used for task logs."
  value       = aws_cloudwatch_log_group.tasks.arn
}

output "capacity_provider_names" {
  description = "Registered capacity provider names (always includes FARGATE)."
  value       = aws_ecs_cluster_capacity_providers.this.capacity_providers
}

output "compliance_controls" {
  description = "Compliance state for OPA / drift evaluation."
  value = {
    environment         = var.environment
    region              = var.region
    allowed_regions     = var.allowed_regions
    encryption_at_rest  = var.kms_key_arn != null
    multi_az            = var.high_availability.multi_az
    retention_days      = var.backup.log_retention_days
    data_classification = var.data_classification
    fargate_first       = true
  }
}