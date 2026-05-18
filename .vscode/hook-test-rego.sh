#!/usr/bin/env bash
# Claude Code PostToolUse hook: re-runs full conftest check when a .rego policy file is edited.
set -euo pipefail

FILE=$(jq -r '.tool_input.file_path // empty')
[[ -z "$FILE" ]] && exit 0
[[ "$FILE" =~ /policies/.*\.rego$ ]] || exit 0

REPO_ROOT=$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel)

mapfile -d '' TF_FILES < <(
  find "$REPO_ROOT/common-resources" -name "*.tf" \
    ! -path "*/.terraform/*" ! -path "*/tests/*" -print0
)
[[ ${#TF_FILES[@]} -eq 0 ]] && exit 0

echo "→ conftest: $(basename "$FILE")"
conftest test "${TF_FILES[@]}" \
  --policy "$(dirname "$FILE")" \
  --parser hcl2 \
  --all-namespaces \
  --no-color
