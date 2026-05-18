#!/bin/bash
set -euo pipefail

export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"

echo "🔍 Procurando diretórios com testes..."

pids=()
modules=()
logs=()
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

while IFS= read -r -d '' test_dir; do
  if compgen -G "$test_dir"/*.tftest.hcl > /dev/null; then
    module_dir=$(dirname "$test_dir")
    logfile="$tmpdir/$(echo "$module_dir" | tr '/' '_').log"
    echo "▶ Starting tests: $module_dir"
    (
      cd "$module_dir"
      start=$SECONDS
      if [[ ! -d .terraform/providers ]]; then
        tofu init -input=false
      fi
      tofu test -test-directory=tests --verbose
      echo "⏱  ${module_dir}: $((SECONDS - start))s"
    ) > "$logfile" 2>&1 &
    pids+=($!)
    modules+=("$module_dir")
    logs+=("$logfile")
  fi
done < <(find common-resources -type d -name tests -not -path "*/\_template/*" -print0)

if [[ ${#pids[@]} -eq 0 ]]; then
  echo "⚠️  Nenhum diretório de testes encontrado."
  exit 0
fi

failed=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Falhou: ${modules[$i]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "${logs[$i]}"
    failed=1
  else
    elapsed=$(grep -o '⏱.*' "${logs[$i]}" || echo "")
    echo "✅ Passou: ${modules[$i]} ${elapsed#*  }"
  fi
done

if [[ $failed -ne 0 ]]; then
  echo ""
  echo "❌ Alguns testes falharam!"
  exit 1
fi

echo "✅ Tests executed with success!"
exit 0
