#!/usr/bin/env bash
# OPA coverage check:
#   - Types NOT in required_tags.skip_types are covered by the generic tags policy → OK.
#   - Types IN skip_types bypass required_tags, so they need explicit coverage in another policy.
#   - CRITICAL_SKIP_TYPES are the subset of skip_types that carry real security risk; a missing
#     policy for them is a hard failure.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUIRED_TAGS_REGO="$REPO_ROOT/policies/terraform/required_tags.rego"

# Types in skip_types that MUST have explicit policy coverage.
# Only list types that are already covered — new uncovered critical types added here will enforce policy creation.
CRITICAL_SKIP_TYPES=(
  "aws_s3_bucket_public_access_block"
  "aws_s3_bucket_acl"
)

echo "🔍 OPA coverage check — AWS resource types vs. policies..."

# ── 1. Resource types actually used in the codebase ─────────────────────────
USED=$(grep -rh --include="*.tf" \
  'resource[[:space:]]*"aws_' "$REPO_ROOT/common-resources" 2>/dev/null \
  | grep -oP '"aws_[^"]+' | tr -d '"' | sort -u) || true

if [[ -z "$USED" ]]; then
  echo "✅ No AWS resource types found in common-resources/"
  exit 0
fi

# ── 2. Types exempted from required_tags (skip_types set) ───────────────────
SKIP_TYPES=$(grep -oP '"aws_[^"]+' "$REQUIRED_TAGS_REGO" 2>/dev/null \
  | tr -d '"' | sort -u) || true

# ── 3. Types explicitly referenced in policies OTHER than required_tags ──────
#    Note: use [a-z0-9_]+ to correctly match types with digits (e.g. aws_s3_bucket)
EXPLICITLY_COVERED=$(grep -rh --include="*.rego" \
  --exclude="required_tags.rego" \
  'aws_' "$REPO_ROOT/policies" 2>/dev/null \
  | grep -oP 'aws_[a-z0-9_]+' | sort -u) || true

# ── 4. Find used types that are in skip_types but not explicitly covered ─────
UNCOVERED=()
while IFS= read -r type; do
  if echo "$SKIP_TYPES" | grep -q "^${type}$"; then
    if ! echo "$EXPLICITLY_COVERED" | grep -q "^${type}$"; then
      UNCOVERED+=("$type")
    fi
  fi
done <<< "$USED"

FAILED=0

if [[ ${#UNCOVERED[@]} -gt 0 ]]; then
  echo "⚠️  Types in required_tags.skip_types with no explicit policy coverage:"
  for t in "${UNCOVERED[@]}"; do
    echo "    - $t"
  done
  echo ""
  echo "   These types bypass the generic tags check — consider adding a targeted rule."
  echo ""

  for critical in "${CRITICAL_SKIP_TYPES[@]}"; do
    for uncovered in "${UNCOVERED[@]}"; do
      if [[ "$uncovered" == "$critical" ]]; then
        echo "❌ '$critical' is a critical skip_type with no policy coverage — add a rule in policies/terraform/"
        FAILED=1
      fi
    done
  done
fi

[[ $FAILED -eq 1 ]] && exit 1
echo "✅ OPA coverage check passed"
