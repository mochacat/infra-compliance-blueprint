# ─────────────────────────────────────────────────────────────────────────────
# VPC module — compliant-by-default VPC with immutable audit logging.
#
# Pillar coverage:
#   1  Encryption:   flow logs encrypted at rest via SSE-S3 by AWS (or a caller CMK)
#   3  Network:      private subnets only, no public IPs, no 0.0.0.0/0 routes
#   4  HA:           subnets span at least 2 AZs, multi-AZ enforced
#   5  Observability: VPC flow logs → centralized immutable audit bucket (S3)
#   7  Residency:    data_classification + data_residency tags and gates
#   8  Audit:        flow logs go to offsite (Log Archive) bucket — single invariant store
#  10  FinOps:       CostCenter / Project tags
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # ── CIDR overlap detection (Pillar 3 / network isolation) ───────────────────
  # Convert the proposed CIDR's first and last IP to 32-bit integers for
  # numeric overlap comparison using the formula:
  #   o1*2^24 + o2*2^16 + o3*2^8 + o4
  _this_net_parts  = split(".", cidrhost(var.cidr_block, 0))
  _this_bcst_parts = split(".", cidrhost(var.cidr_block, -1))
  this_start       = parseint(local._this_net_parts[0], 10) * 16777216 + parseint(local._this_net_parts[1], 10) * 65536 + parseint(local._this_net_parts[2], 10) * 256 + parseint(local._this_net_parts[3], 10)
  this_end         = parseint(local._this_bcst_parts[0], 10) * 16777216 + parseint(local._this_bcst_parts[1], 10) * 65536 + parseint(local._this_bcst_parts[2], 10) * 256 + parseint(local._this_bcst_parts[3], 10)

  # Build a list of {start, end} ranges for each reserved CIDR, then check
  # overlap condition: startA ≤ endB ∧ startB ≤ endA
  _reserved_ranges = [
    for rc in var.reserved_cidrs : {
      start = parseint(split(".", cidrhost(rc, 0))[0], 10) * 16777216 + parseint(split(".", cidrhost(rc, 0))[1], 10) * 65536 + parseint(split(".", cidrhost(rc, 0))[2], 10) * 256 + parseint(split(".", cidrhost(rc, 0))[3], 10)
      end   = parseint(split(".", cidrhost(rc, -1))[0], 10) * 16777216 + parseint(split(".", cidrhost(rc, -1))[1], 10) * 65536 + parseint(split(".", cidrhost(rc, -1))[2], 10) * 256 + parseint(split(".", cidrhost(rc, -1))[3], 10)
    }
  ]

  overlaps_any_reserved = anytrue([
    for rr in local._reserved_ranges :
    rr.start <= local.this_end && local.this_start <= rr.end
  ])

  overlap_message = "CIDR block ${var.cidr_block} overlaps one or more reserved CIDRs (var.reserved_cidrs). Cannot create overlapping VPC ranges (Pillar 3 — Network Security & Isolation)."

  # ── Subnet entries ──────────────────────────────────────────────────────────
  # Flatten the caller's subnet map into a list of { tier, az, cidr } entries so
  # they can be iterated in the aws_subnet resource. Each tier must span all
  # provided AZs — this creates one subnet per tier per AZ.
  subnet_entries = flatten([
    for tier_name, tier_config in var.subnets : [
      for az in tier_config.availability_zones : {
        tier = tier_name
        az   = az
        cidr = tier_config.cidrs[index(tier_config.availability_zones, az)]
      }
    ]
  ])

  # ── Tags ────────────────────────────────────────────────────────────────────
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
}
