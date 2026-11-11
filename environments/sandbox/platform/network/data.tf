# ─────────────────────────────────────────────────────────────────────────────
# sandbox/platform/network — data sources
#
# Transit Gateway discovery via RAM (cross-account):
# The network hub shares the TG via RAM. This account accepts the share, and
# the TG is discoverable locally via data.aws_ec2_transit_gateway.
#
# If the TG was not shared (e.g. same-account), pass transit_gateway_id directly.
# ─────────────────────────────────────────────────────────────────────────────

# Cross-account RAM discovery — the hub shared the TG with this account.
# When the variable transit_gateway_id is not set, look it up via RAM.
data "aws_ram_resource_share" "hub" {
  count = var.transit_gateway_id == null ? 1 : 0

  name           = "network-hub-tgw"
  resource_owner = "OTHER-ACCOUNTS"
}

resource "aws_ram_resource_share_accepter" "hub_tg" {
  count = var.transit_gateway_id == null ? 1 : 0

  share_arn = data.aws_ram_resource_share.hub[0].arn
}

data "aws_ec2_transit_gateway" "hub" {
  count = var.transit_gateway_id == null ? 1 : 0

  filter {
    name   = "tag:Name"
    values = ["network-hub-tgw"]
  }

  depends_on = [aws_ram_resource_share_accepter.hub_tg]
}

locals {
  # Resolve TG ID: explicit variable > RAM-discovered > null
  tgw_id = var.transit_gateway_id != null ? var.transit_gateway_id : (
    try(data.aws_ec2_transit_gateway.hub[0].id, null)
  )
}
