# Development / Platform

> **Reference architecture** — a pattern to clone and adapt for your own AWS organization.
> This directory represents one AWS account in the `/Development/Platform` OU.

## Terraservice layering model

Each terraservice is a **separate root module** with its own state, its own apply, and its own
blameless audit trail. They are applied sequentially in dependency order. This section explains
**why this layering is safe**, why downstream layers don't break when upstream layers change, and
what the blast radius of each change actually is.

### The dependency chain

```
iam ──→ network ──→ data ──→ compute
                         └─→ ai
```

Each arrow (`──→`) means "reads the upstream layer's remote state for output values (ARNs, IDs)."

### What "safe" means here

**Layers are never "broken" between applies.** If `iam/` has been applied but `network/` hasn't,
nothing is broken — `network/` simply hasn't been created yet. Each layer is applied sequentially:

```
tofu apply   environments/production/platform/iam/      # creates roles
tofu apply   environments/production/platform/network/   # creates VPC, reads role ARNs from iam/ state
tofu apply   environments/production/platform/data/      # creates RDS, reads subnet IDs from network/ state
tofu apply   environments/production/platform/compute/   # creates ECS, reads from iam/ + network/ + data/
tofu apply   environments/production/platform/ai/        # creates SageMaker, reads from iam/ + network/ + data/
```

### Blast radius analysis

| What changed | Must re-apply | Blast radius | Why it's contained |
|---|---|---|---|
| **iam/** — add a policy to an existing role | `iam/` only | Low | Downstream layers read the role ARN, not the policy content. The new permissions are picked up on their next plan refresh. |
| **iam/** — add a new role | `iam/` only | None | No downstream layer references it until you explicitly add a `terraform_remote_state` data source for it. |
| **iam/** — delete a role | `iam/` + downstream layers | **Controlled by Atlantis** | Atlantis will show downstream layers failing validation because the remote state output is gone. This is caught at plan time, never at apply time. A PR that deletes a role should be reviewed, planned, and applied alongside any downstream cleanup. |
| **network/** — add a new subnet | `network/` only | Low | Data/compute/ai read subnet lists — new subnets appear in their next plan as additions, not breaks. |
| **network/** — change CIDR | `network/` + review downstream | Medium | Downstream layers reference the VPC and subnet IDs, not CIDRs. The IDs don't change on a CIDR modification. VPC CIDR changes require recreation — `prevent_destroy` is not set on the VPC but the lifecycle precondition prevents CIDR overlap. |
| **network/** — delete VPC | terraform destroy chain | **Full blast, by design** | You don't delete a VPC with resources in it. Downstream layers' `terraform_remote_state` will break — but this is a deliberate decommissioning action, not a routine change. |
| **data/** — add DB instance | `data/` only | None | Compute/ai read connection endpoints, not the existence of instances. |
| **compute/** or **ai/** — modify service | That layer only | None | No downstream layers depend on compute or ai. |

### The key insight

The only "dangerous" changes are **removing an output that downstream layers depend on**. This is:

1. **Caught at plan time** — `terraform_remote_state` shows the output as `no longer present`
2. **Gated by Atlantis** — every apply requires a plan review
3. **Requires a PR** — deleting a role is a deliberate code change, not an accident

In practice, the most common change (adding a new permission to an existing role in `iam/`) has
zero blast radius beyond `iam/` itself. This is the standard multi-layer pattern used by regulated
AWS organizations at scale — it keeps state files small, plans fast, and audit trails precise.

### Why not one big state?

| Concern | One state per layer | One big state |
|---|---|---|
| Plan time | Seconds (each layer ~50 resources) | Minutes (hundreds of resources) |
| Blast radius | One terraservice | The entire account |
| Apply parallelism | None needed (sequential by design) | Impossible (one apply at a time) |
| Atlantis approval | Per-layer granularity (dev vs prod gates) | All-or-nothing |
| Team ownership | Each team owns their layer's directory | Shared file = merge conflicts |
| History | Per-layer state | Monolithic — hard to `tofu state mv` |

### The one risk you must guard against

If you apply a change that **removes or renames** an upstream output, downstream layers will fail
on their next plan. The discipline is:

> **Never remove an output from `outputs.tf` without checking `terraform_remote_state` references
> across all downstream layers in the same environment.**

This is enforced by the PR review process, not by code — and it's sufficient for an early-stage
team. As you scale, add `opa eval` rules that detect `terraform_remote_state` references to
nonexistent outputs.
