# ─────────────────────────────────────────────────────────────────────────────
# network-hub / transit-gateway terraservice — main
#
# Infra-team OWNED control-plane layer. One-of-a-kind shared infrastructure, so
# the Transit Gateway is inlined here (it has no reusable module) rather than
# composed. Every workload `network/` terraservice attaches here and reads the
# TG id from SSM (see outputs.tf / locals.tf).
#
# Pillar coverage:
#   3  Network Security & Isolation: the hub that all workload VPCs join
#   4  HA & Region Control:           region gated to allowed_regions
#   7  Data Residency:               classification + PHI-sovereign gate
#  10  FinOps:                        cost allocation tags
# ─────────────────────────────────────────────────────────────────────────────

# ── Transit Gateway (the hub itself) ─────────────────────────────────────────
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Shared network hub for ${var.environment} workloads (infra-team owned)."
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments
  default_route_table_association = var.default_route_table_association
  default_route_table_propagation = var.default_route_table_propagation

  tags = merge(local.base_tags, { Name = local.hub_name })

  lifecycle {
    # Region gate (Pillar 4) — deployed only in approved regions.
    precondition {
      condition     = contains(var.allowed_regions, var.region)
      error_message = "Region ${var.region} is not in approved allowed_regions (Pillar 4 — High Availability & Region Control)."
    }
    # Residency gate (Pillar 7) — PHI requires sovereign_only.
    precondition {
      condition     = (var.data_residency.sovereign_only == true || var.data_classification != "phi")
      error_message = "PHI requires sovereign_only = true (Pillar 7 — Data Residency & Sovereignty)."
    }
  }
}

# ── Cross-account discovery via RAM (the load-bearing contract) ──────────────
# Workload accounts do NOT read an SSM param for the TG id — SSM lives in one
# account and can't be read cross-account. Instead the TG is SHARED via RAM; each
# workload account accepts the share and looks the shared TG up in its OWN account
# via data.aws_ec2_transit_gateway (same TG id on both sides). Least privilege:
# every principal is named explicitly, never a wildcard (Pillar 2).
resource "aws_ram_resource_share" "this" {
  name                      = local.hub_name
  allow_external_principals = false

  tags = local.base_tags

  lifecycle {
    precondition {
      condition     = length(var.participants) >= 1 || var.environment == "dev"
      error_message = "A prod/test hub must name at least one workload account to share the TG with (Pillar 2 — Access Control & Least Privilege)."
    }
    prevent_destroy = true
  }
}

# Associates the shared TG with the RAM share (one association per resource ARN).
resource "aws_ram_resource_association" "transit_gateway" {
  resource_share_arn = aws_ram_resource_share.this.arn
  resource_arn       = aws_ec2_transit_gateway.this.arn
}

resource "aws_ram_principal_association" "this" {
  for_each = toset(var.participants)

  resource_share_arn = aws_ram_resource_share.this.arn
  principal          = each.value
}

# ── Same-account pointer for humans + audits (NOT the cross-account contract) ─
# Kept as a convenience: a human or same-account tool can read the TG id without
# listing resources. Workload network/ layers rely on RAM, not this param.
resource "aws_ssm_parameter" "transit_gateway_id" {
  # checkov:skip=CKV2_AWS_34:Parameter is `type = "String"` (holds only a non-secret TG id) but IS encrypted at rest with the caller-provided CMK via `key_id`. Checkov only honors this check for `SecureString`. Encryption-at-rest is still enforced (Pillar 1).
  name        = local.ssm_parameter_name
  description = "ID of the shared Transit Gateway. Cross-account consumer discovery is via RAM share, not this parameter (parameter is a same-account/human pointer)."
  type        = "String"
  value       = aws_ec2_transit_gateway.this.id
  key_id      = var.kms_key_arn

  tags = local.base_tags

  lifecycle {
    prevent_destroy = true
  }
}