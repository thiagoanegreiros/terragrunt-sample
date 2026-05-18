#!/usr/bin/env bash
# Claude Code PostToolUse hook: runs tflint on the top-level module that contains the edited .tf file.
set -euo pipefail

FILE=$(jq -r '.tool_input.file_path // empty')
[[ -z "$FILE" ]] && exit 0
[[ "$FILE" =~ /common-resources/.*\.tf$ ]] || exit 0

REPO_ROOT=$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel)
MODULE_DIR=$(dirname "$FILE")

RELATIVE=${MODULE_DIR#$REPO_ROOT/common-resources/}
TOP_MODULE="${RELATIVE%%/*}"
MODULE_PATH="$REPO_ROOT/common-resources/$TOP_MODULE"

echo "→ tflint: common-resources/$TOP_MODULE"
tflint \
  --chdir "$MODULE_PATH" \
  --config "$REPO_ROOT/.tflint.hcl" \
  --minimum-failure-severity=error
