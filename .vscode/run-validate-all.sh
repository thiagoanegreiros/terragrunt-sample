#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔍 Running tofu validate on all modules..."
PASSED=0 SKIPPED=0

while IFS= read -r module_dir; do
  rel=$(realpath --relative-to="$REPO_ROOT" "$module_dir")
  if [[ -d "$module_dir/.terraform" ]]; then
    echo "▶ $rel"
    (cd "$module_dir" && tofu validate -no-color) || exit 1
    PASSED=$((PASSED + 1))
  else
    echo "⚠  Skipping (not initialized): $rel"
    SKIPPED=$((SKIPPED + 1))
  fi
done < <(
  find "$REPO_ROOT/common-resources" -name "*.tf" \
    ! -path "*/.terraform/*" ! -path "*/tests/*" \
    -exec dirname {} \; | sort -u
)

echo "✅ tofu validate: $PASSED passed, $SKIPPED skipped (not initialized)"
