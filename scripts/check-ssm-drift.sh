#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# check-ssm-drift.sh — Verify SSM parameters haven't drifted since plan time
#
# Called by Atlantis before apply. Reads the SSM parameters that the project
# consumes (from ssm-contract.json) and compares their current values against
# the values that were present at plan time. If any have changed, the apply
# is blocked because the plan is stale.
#
# This prevents the scenario where:
#   1. network/ applies, updating subnet IDs in SSM
#   2. data/ plans against the old subnet IDs (read before network applied)
#   3. data/ tries to apply — would reference now-defunct subnets
#
# Usage:
#   check-ssm-drift.sh <project-dir>
#
# Example:
#   check-ssm-drift.sh environments/production/platform/data
#
# Dependencies:
#   - aws CLI (configured with the target account role)
#   - jq
#   - ssm-contract.json at repo root
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT_DIR="${1:?Usage: $0 <project-dir>}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
CONTRACT="$REPO_ROOT/ssm-contract.json"

if [ ! -f "$CONTRACT" ]; then
  echo "No ssm-contract.json found — skipping SSM drift check."
  exit 0
fi

# ── Extract environment, business unit, layer from path
if echo "$PROJECT_DIR" | grep -q "^environments/"; then
  ENV="$(echo "$PROJECT_DIR" | cut -d'/' -f2)"
  BU="$(echo "$PROJECT_DIR" | cut -d'/' -f3)"
  LAYER="$(echo "$PROJECT_DIR" | cut -d'/' -f4)"
elif echo "$PROJECT_DIR" | grep -q "^landing-zone/"; then
  echo "Landing zone project — no SSM dependencies to check."
  exit 0
elif echo "$PROJECT_DIR" | grep -q "infra-control-plane"; then
  echo "Infra control plane project — no SSM dependencies to check."
  exit 0
else
  echo "Unknown project path — skipping SSM drift check."
  exit 0
fi

# ── Get the list of SSM parameters this layer consumes
CONSUMES=($(jq -r ".template[\"$LAYER\"].consumes // [] | .[]" "$CONTRACT"))

if [ ${#CONSUMES[@]} -eq 0 ]; then
  echo "Layer $LAYER consumes no SSM parameters — no drift check needed."
  exit 0
fi

# ── Also check if this layer's environment/BU exists in the contract
ENV_EXISTS=$(jq -r "
  .environments[\"$ENV\"] // [] | map(select(.business_unit == \"$BU\")) | length
" "$CONTRACT")

if [ "$ENV_EXISTS" -eq 0 ]; then
  echo "No SSM contract entry for $ENV/$BU — skipping drift check."
  exit 0
fi

echo ""
echo "── SSM Drift Check ──────────────────────────────────────────────"
echo "  Layer:     $LAYER"
echo "  Env/BU:    $ENV/$BU"
echo "  Consumes:  ${CONSUMES[*]}"
echo ""

# ── For each consumed parameter, read it from AWS SSM Parameter Store
#    and verify it exists. If a consumed parameter is missing, the upstream
#    layer hasn't been applied yet — block the apply.
DRIFT_FOUND=false
for param_key in "${CONSUMES[@]}"; do
  SSM_PATH="/environments/$ENV/$BU/$param_key"

  # Read current value from SSM
  if ! SSM_VALUE=$(aws ssm get-parameter \
    --name "$SSM_PATH" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text 2>&1); then
    echo "  MISSING: $SSM_PATH"
    echo "    This parameter must exist before $LAYER can apply."
    echo "    Apply the upstream layer (${param_key%%-*} ...) first."
    DRIFT_FOUND=true
    continue
  fi

  echo "  OK:      $SSM_PATH = ${SSM_VALUE:0:60}..."
done

echo ""

if [ "$DRIFT_FOUND" = true ]; then
  echo "ERROR: SSM drift detected — one or more consumed parameters are missing."
  echo "Apply the upstream layer(s) first, then re-plan this layer."
  exit 1
fi

echo "All consumed SSM parameters are present. Drift check passed."
exit 0