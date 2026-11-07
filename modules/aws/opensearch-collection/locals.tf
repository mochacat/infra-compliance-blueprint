# ─────────────────────────────────────────────────────────────────────────────
# opensearch-collection module — locals
# ─────────────────────────────────────────────────────────────────────────────

locals {
  collection_name = var.collection.name != null ? var.collection.name : var.name

  base_tags = merge(
    var.default_tags,
    {
      ManagedBy          = "tofu"
      Environment        = var.environment
      Region             = var.region
      CostCenter         = var.cost_controls.cost_center
      Project            = var.cost_controls.project_code
      DataClassification = var.data_classification
      Jurisdiction       = var.data_residency.jurisdiction
    }
  )

  # Vector dimension is embedded in the collection description for traceability,
  # matching the embedding model used by the caller.
  collection_description = var.collection.description != null ? var.collection.description : "Vector store for ${var.environment} RAG pipelines (${var.collection.vector_dimension}-dim)"

  # Encryption security policy targets this collection name + pattern.
  encryption_policy_json = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.collection_name}"]
      }
    ]
    AWSOwnedKey = false
    KmsARN      = var.kms_key_arn
  })

  # Network security policy — ALWAYS private, only the module's VPC endpoint.
  network_policy_json = jsonencode([
    {
      Description = "Private access for ${local.collection_name}"
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${local.collection_name}"]
        }
      ]
      AllowFromPublic = false
      SourceVPCEs     = [aws_opensearchserverless_vpc_endpoint.this.id]
    }
  ])

  # Data access policy — least privilege: ONLY the caller's principals can
  # search/write on this collection.
  access_policy_json = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${local.collection_name}/*"]
          Permission   = ["aoss:ReadDocument", "aoss:WriteDocument"]
        }
      ]
      Principal = var.iam.principal_arns
    }
  ])

  # Data lifecycle policy — index retention.
  lifecycle_policy_json = jsonencode({
    Rules = [
      {
        ResourceType      = "index"
        Resource          = ["index/${local.collection_name}/*"]
        MinIndexRetention = "Unlimited"
      }
    ]
  })
}