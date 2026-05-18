#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POLICY_DIR="${REPO_ROOT}/policies"

echo "🔍 Running Conftest policy checks on common-resources/..."

mapfile -d '' tf_files < <(
  find "${REPO_ROOT}/common-resources" \
    -name "*.tf" \
    ! -path "*/.terraform/*" \
    ! -path "*/tests/*" \
    -print0
)

if [[ ${#tf_files[@]} -eq 0 ]]; then
  echo "⚠️  No .tf files found in common-resources/"
  exit 0
fi

conftest test "${tf_files[@]}" \
  --policy "${POLICY_DIR}" \
  --parser hcl2 \
  --all-namespaces \
  --no-color

echo "✅ Conftest: all policies passed"
