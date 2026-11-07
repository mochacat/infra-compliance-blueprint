module "compute" {
  source = "../../"

  environment = var.environment
  name        = var.name
  region      = var.region
  kms_key_arn = var.kms_key_arn
  network = {
    vpc_id             = var.vpc_id
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }
  data_classification = var.data_classification
  observability = {
    alarm_topic_arn = var.alarm_topic_arn
  }
  default_tags = {
    CostCenter = "platform-ai"
    Project    = "rag"
  }
}