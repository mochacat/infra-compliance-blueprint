#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# check-downstream.sh — Identify downstream layers affected by a change
#
# Called by Atlantis after plan. Reads the SSM contract and the plan JSON to
# determine which layers depend on the changed project. Prints a warning to
# the Atlantis output (visible in the PR comment) if downstream layers need
# re-planning.
#
# Usage:
#   check-downstream.sh <project-dir> <plan-json-path>
#
# Example:
#   check-downstream.sh environments/production/platform/network plan.json
#
# Dependencies:
#   - jq (install in Atlantis container)
#   - ssm-contract.json at repo root
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT_DIR="${1:?Usage: $0 <project-dir> <plan-json-path>}"
PLAN_JSON="${2:?Usage: $0 <project-dir> <plan-json-path>}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
CONTRACT="$REPO_ROOT/ssm-contract.json"

if [ ! -f "$CONTRACT" ]; then
  echo "No ssm-contract.json found — skipping downstream check."
  exit 0
fi

if [ ! -f "$PLAN_JSON" ]; then
  echo "No plan JSON at $PLAN_JSON — skipping downstream check."
  exit 0
fi

# ── Extract the environment, business unit, and layer from the directory path
# Path pattern: environments/<env>/<bu>/<layer>  OR  landing-zone/<layer>
if echo "$PROJECT_DIR" | grep -q "^environments/"; then
  ENV="$(echo "$PROJECT_DIR" | cut -d'/' -f2)"
  BU="$(echo "$PROJECT_DIR" | cut -d'/' -f3)"
  LAYER="$(echo "$PROJECT_DIR" | cut -d'/' -f4)"
elif echo "$PROJECT_DIR" | grep -q "^landing-zone/"; then
  echo "Landing zone project — no SSM downstream dependencies."
  exit 0
elif echo "$PROJECT_DIR" | grep -q "infra-control-plane"; then
  echo "Infra control plane project — no SSM downstream dependencies."
  exit 0
else
  echo "Unknown project path pattern — skipping downstream check."
  exit 0
fi

# ── Check if the plan actually creates/updates/deletes any resources
RESOURCE_CHANGES="$(jq '.resource_changes // [] | length' "$PLAN_JSON")"
OUTPUT_CHANGES="$(jq '.output_changes // {} | length' "$PLAN_JSON")"

if [ "$RESOURCE_CHANGES" -eq 0 ] && [ "$OUTPUT_CHANGES" -eq 0 ]; then
  echo "No resource or output changes — no downstream impact."
  exit 0
fi

# ── Get the published parameters for this layer from the contract
PUBLISHED_PARAMS="$(jq -r "
  .template[\"$LAYER\"].publishes // []
  | join(\", \")
" "$CONTRACT")"

# ── Get downstream layers (higher apply_order) for this environment/BU
ALL_LAYERS="$(jq -r "
  .environments[\"$ENV\"][] | select(.business_unit == \"$BU\") | .layers[]
" "$CONTRACT" 2>/dev/null || true)"

# ── If no environment/BU match in the contract, try infrastructure section
if [ -z "$ALL_LAYERS" ]; then
  INFRA_LAYERS="$(jq -r "
    .infrastructure[\"$BU\"] // {} | keys[]
  " "$CONTRACT" 2>/dev/null || true)"
  if [ -n "$INFRA_LAYERS" ]; then
    ALL_LAYERS="$INFRA_LAYERS"
  fi
fi

if [ -z "$ALL_LAYERS" ]; then
  echo "No SSM contract entry for $ENV/$BU — skipping downstream check."
  exit 0
fi

# ── Get the apply_order of the changed layer
LAYER_ORDER="$(jq -r ".template[\"$LAYER\"].apply_order // 99" "$CONTRACT")"

# ── Find downstream layers that depend on what this layer publishes
DOWNSTREAM_LAYERS=""
for candidate in $ALL_LAYERS; do
  CAND_ORDER="$(jq -r ".template[\"$candidate\"].apply_order // 99" "$CONTRACT")"
  if [ "$CAND_ORDER" -le "$LAYER_ORDER" ]; then
    continue  # upstream or same layer — skip
  fi

  # Check if candidate consumes any of our published params
  CONSUMES="$(jq -r ".template[\"$candidate\"].consumes // [] | join(\",\")" "$CONTRACT")"
  for pub in $(jq -r ".template[\"$LAYER\"].publishes // [] | .[]" "$CONTRACT"); do
    if echo "$CONSUMES" | grep -q "$pub"; then
      DOWNSTREAM_LAYERS="$DOWNSTREAM_LAYERS $candidate"
      break
    fi
  done
done

if [ -z "$DOWNSTREAM_LAYERS" ]; then
  echo "No downstream layers consume this layer's published parameters."
  exit 0
fi

# ── Print warning
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  DOWNSTREAM DEPENDENCY WARNING                                      ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Layer:     $LAYER (apply order $LAYER_ORDER)"
echo "║  Env/BU:    $ENV/$BU"
echo "║  Changes:   $RESOURCE_CHANGES resources, $OUTPUT_CHANGES outputs"
echo "║  Publishes: $PUBLISHED_PARAMS"
echo "║"
echo "║  The following downstream layers may be affected and need           ║"
echo "║  re-planning before apply:                                          ║"
for dl in $DOWNSTREAM_LAYERS; do
  DL_ORDER="$(jq -r ".template[\"$dl\"].apply_order // 99" "$CONTRACT")"
  printf "║    - %s (apply order %s)\n" "$dl" "$DL_ORDER"
done
echo "║"
echo "║  Apply order must be: $LAYER →$DOWNSTREAM_LAYERS"
echo "║  Run '/atlantis plan -p <downstream-project>' to re-plan.          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Exit cleanly — this is informational, not a blocker. The SSM drift check
# before apply will catch stale plans.
exit 0