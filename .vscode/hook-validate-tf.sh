#!/usr/bin/env bash
# Claude Code PostToolUse hook: runs tofu validate on the edited module.
# Only fires when the module is already initialized (.terraform exists).
set -euo pipefail

FILE=$(jq -r '.tool_input.file_path // empty')
[[ -z "$FILE" ]] && exit 0
[[ "$FILE" =~ /common-resources/.*\.tf$ ]] || exit 0

MODULE_DIR=$(dirname "$FILE")
[[ -d "$MODULE_DIR/.terraform" ]] || exit 0

echo "→ tofu validate: $(basename "$MODULE_DIR")"
cd "$MODULE_DIR" && tofu validate -no-color
