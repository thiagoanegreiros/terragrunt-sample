#!/usr/bin/env bash
# Claude Code PreToolUse hook: blocks 'terragrunt apply' from running via Claude Code.
# Apply must always be run manually by the user after reviewing the plan.
COMMAND=$(jq -r '.tool_input.command // empty')
echo "$COMMAND" | grep -qE 'terragrunt[[:space:]]+apply' || exit 0

echo "BLOCKED: 'terragrunt apply' cannot be run via Claude Code."
echo "Show the plan with 'terragrunt plan' and ask the user to execute apply manually."
exit 1
