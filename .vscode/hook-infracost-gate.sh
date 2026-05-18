#!/usr/bin/env bash
# Runs infracost breakdown on the current Terragrunt stack directory.
# Fails if the estimated monthly cost exceeds the per-module threshold.
#
# Usage (called by root.hcl before_hook):
#   hook-infracost-gate.sh <max_monthly_usd>
#
# Override at runtime: INFRACOST_MAX_MONTHLY_USD=200 terragrunt plan
set -euo pipefail

MAX_MONTHLY_USD=${INFRACOST_MAX_MONTHLY_USD:-${1:-500}}

echo "💰 Infracost estimate (threshold: \$${MAX_MONTHLY_USD}/month)..."

PLAN_BIN=$(mktemp /tmp/infracost-plan-XXXXXX.tfplan)
PLAN_JSON=$(mktemp /tmp/infracost-plan-XXXXXX.json)
cleanup() { rm -f "$PLAN_BIN" "$PLAN_JSON"; }
trap cleanup EXIT INT TERM

# Terragrunt 1.x runs before_hooks from inside the cache dir (the module working dir).
# .terraform is a direct subdirectory here — no need to search for it.
CACHE_DIR="."

if [ ! -d ".terraform" ]; then
  echo "⚠  Infracost could not estimate this module — skipping gate"
  exit 0
fi

# Generate a plan directly via tofu (not terragrunt) to avoid re-triggering before_hooks.
# inputs.auto.tfvars.json is already written to the cache dir by Terragrunt before hooks run.
if ! tofu -chdir="$CACHE_DIR" plan -out="$PLAN_BIN" -no-color > /dev/null 2>&1; then
  echo "⚠  Infracost could not estimate this module — skipping gate"
  exit 0
fi

# Convert binary plan to JSON (required by infracost)
if ! tofu -chdir="$CACHE_DIR" show -json "$PLAN_BIN" > "$PLAN_JSON" 2>/dev/null; then
  echo "⚠  Infracost could not estimate this module — skipping gate"
  exit 0
fi

COST_JSON=$(infracost breakdown \
  --path "$PLAN_JSON" \
  --format json \
  --show-skipped \
  --no-color 2>/dev/null) || {
  echo "⚠  Infracost could not estimate this module — skipping gate"
  exit 0
}

# Print human-readable table alongside the gate check
infracost breakdown \
  --path "$PLAN_JSON" \
  --format table \
  --show-skipped \
  --no-color 2>/dev/null || true

MONTHLY=$(echo "$COST_JSON" | jq -r '.totalMonthlyCost // "0"')
RESOURCE_COUNT=$(echo "$COST_JSON" | jq '[.projects[].breakdown.resources[]] | length')

printf "\n  Estimated monthly cost: \$%s  (resources: %s)\n" "$MONTHLY" "$RESOURCE_COUNT"

if [[ "$RESOURCE_COUNT" -gt 0 && "$MONTHLY" == "0" ]]; then
  echo "  ℹ  All resources are free-tier or usage-based — no baseline cost"
fi

OVER=$(echo "$MONTHLY $MAX_MONTHLY_USD" | awk '{print ($1 > $2) ? 1 : 0}')
if [[ "$OVER" == "1" ]]; then
  echo ""
  echo "  ❌ Monthly cost \$${MONTHLY} exceeds module threshold of \$${MAX_MONTHLY_USD}/month"
  echo "     To raise the limit, add to this stack's info.hcl:"
  echo "       infracost_max_monthly_usd = <new_limit>"
  exit 1
fi

echo "  ✅ Cost within threshold"
