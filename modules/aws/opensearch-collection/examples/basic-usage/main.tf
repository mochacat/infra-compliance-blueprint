# Basic usage — module invocation.

module "rag_vector_store" {
  source = "../../../opensearch-collection"

  environment = "dev"
  name        = "basic-rag"
  region      = var.region
  kms_key_arn = var.kms_key_arn

  network = {
    vpc_id             = var.vpc_id
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  iam = {
    principal_arns = [var.app_role_arn]
  }

  collection = {
    type             = "VECTORSEARCH"
    vector_dimension = 1536 # matches text-embedding-3-large
  }

  data_classification = "internal"
}