# workload `<env>/<bu>/network/` — consumer of the shared hub TG

> Reference for the **workload-account** side of the cross-account TG contract. Runs in a
> **different AWS account** than `infrastructure/network-hub/transit-gateway`.

Discovery is via **RAM**, not SSM (an SSM param is account-local and can't be read cross-account):

1. The hub already shared the TG with this account (`participants` in the hub terraservice).
2. This layer **accepts** the share with `aws_ram_resource_share_accepter`.
3. It looks the shared TG up **in its own account** with `data.aws_ec2_transit_gateway`
   (same TG id on both sides).
4. It attaches its VPC via the `transit-gateway-attachment` module using that id.

```hcl
# Accept the hub's RAM share of the Transit Gateway (must match the hub's share ARN).
data "aws_ram_resource_share" "hub" {
  share_owner = "self"
  name        = "network-hub-tgw"
}

resource "aws_ram_resource_share_accepter" "hub_tg" {
  share_arn = data.aws_ram_resource_share.hub.id
}

# The shared TG appears locally after accept → look it up in THIS account.
data "aws_ec2_transit_gateway" "hub" {
  depends_on = [aws_ram_resource_share_accepter.hub_tg]
  tags = { Name = "network-hub-tgw" }
}

module "tgw_attachment" {
  source              = "git::...?ref=vX.Y.Z"   # modules/aws/transit-gateway-attachment
  transit_gateway_id  = data.aws_ec2_transit_gateway.hub.id
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  data_classification = "pii"
  environment         = var.environment
  # + region, allowed_regions, data_residency, network, cost_controls
}
```

> This is a reference pattern for an infra team to clone and adapt — it is not applied by default.