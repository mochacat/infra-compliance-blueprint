# ─────────────────────────────────────────────────────────────────────────────
# sagemaker-domain module — locals
# ─────────────────────────────────────────────────────────────────────────────

locals {
  base_tags = merge(
    var.default_tags,
    {
      ManagedBy          = "tofu"
      Environment        = var.environment
      Region             = var.region
      CostCenter         = var.cost_controls != null ? var.cost_controls.cost_center : null
      Project            = var.cost_controls != null ? var.cost_controls.project_code : null
      DataClassification = var.data_classification
      Jurisdiction       = var.data_residency.jurisdiction
    }
  )

  execution_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Scoped S3 data access — only the named buckets.
        {
          Sid    = "SageMakerS3Data"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
          ]
          Resource = concat(
            var.sagemaker_bucket_arns,
            [for b in var.sagemaker_bucket_arns : "${b}/*"]
          )
        },
        # Scoped ECR image pull — only the named repositories.
        {
          Sid    = "SageMakerECR"
          Effect = "Allow"
          Action = [
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:GetAuthorizationToken",
          ]
          Resource = var.sagemaker_repository_arns
        },
      ],
      # Optional additional managed-policy-style grants are appended as
      # allow stmts by the caller; wildcard Resource is forbidden in this
      # module and is blocked by the OPA rule below.
      []
    )
  })

  execution_role_assume_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}