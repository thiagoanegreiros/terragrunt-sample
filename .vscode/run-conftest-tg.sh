#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POLICY_DIR="${REPO_ROOT}/policies/terragrunt"

echo "🔍 Running Conftest Terragrunt policy checks on common-resources/..."

mapfile -d '' hcl_files < <(
  find "${REPO_ROOT}/common-resources" \
    -name "*.hcl" \
    ! -path "*/.terraform/*" \
    -print0
)

if [[ ${#hcl_files[@]} -eq 0 ]]; then
  echo "⚠️  No .hcl files found in common-resources/"
  exit 0
fi

conftest test "${hcl_files[@]}" \
  --policy "${POLICY_DIR}" \
  --parser hcl2 \
  --all-namespaces \
  --no-color

echo "✅ Conftest TG: all policies passed"
