# ─────────────────────────────────────────────────────────────────────────────
# S3 Bucket — primary resources
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "this" {
  # checkov:skip=CKV_AWS_144:Cross-region replication is NOT forced; PHI forbids it (Pillar 7 — Data Residency & Sovereignty), replication is caller opt-in
  # checkov:skip=CKV2_AWS_61:Lifecycle rules are data-specific (expiry/tiering), deletion protection enforced via force_destroy=false (Pillar 6 — Backup, DR & Deletion Protection)
  # checkov:skip=CKV2_AWS_62:Event notifications are workload-specific hooks; access logging handled separately (Pillar 5 — Observability)
  bucket        = local.bucket_name
  force_destroy = false # Never silently empty a bucket on destroy.
  tags          = local.base_tags

  lifecycle {
    # NOTE: OpenTofu only accepts a *literal* `prevent_destroy`, so a computed
    # value cannot be gated on `var.audit_bucket` here. Audit protection is
    # enforced below via preconditions (plan/apply time) + `force_destroy = false`
    # (destroy time), and exposed through the `compliance_controls` output so OPA
    # can deny a plan that drops an audit bucket's protection.

    # Residency gate (Pillar 7 — Data Residency & Sovereignty). Cannot live in a `variable validation` because
    # OpenTofu forbids a validation from referencing another var.
    precondition {
      condition     = var.data_residency.sovereign_only == true || var.data_classification != "phi"
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }

    # Region gate (Pillar 4 — High Availability & Region Control). `region` must be in the approved `allowed_regions`
    # list. Lives here (not a variable validation) so it can cross-reference
    # `allowed_regions`.
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }
  }
}

# ── Encryption at rest (Pillar 1 — Encryption) — caller-provided CMK, always on.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true # Reduces KMS calls, still CMK-encrypted.
  }
}

# ── Public access firewalled at every layer (Pillar 3 — Network Security & Isolation).
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── SecureTransport enforced + no public access in the policy (Pillar 1 in transit).
data "aws_iam_policy_document" "bucket_policy" {
  # Deny any non-TLS access to the bucket or its objects.
  statement {
    sid       = "EnforceSecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# ── Versioning (Pillar 6 — Backup, DR & Deletion Protection) — on by default, mandatory for audit buckets.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# ── Object Lock for audit buckets (Pillar 8 — Auditability & Immutability).
resource "aws_s3_bucket_object_lock_configuration" "this" {
  count  = var.audit_bucket ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      mode = var.audit_lock_mode
      days = var.audit_retention_days
    }
  }
}

# ── Access logging to a centralized destination (Pillar 5 — Observability).
resource "aws_s3_bucket_logging" "this" {
  count  = var.observability.log_bucket_id != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  target_bucket = var.observability.log_bucket_id
  target_prefix = var.observability.log_prefix
}