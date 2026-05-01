#!/usr/bin/env bash
set -euo pipefail

STATUS_FILE="${1:-segkit/migration-status.json}"

if [ ! -f "$STATUS_FILE" ]; then
  echo "Error: $STATUS_FILE not found" >&2
  exit 1
fi

shell=$(jq '.summary.shell' "$STATUS_FILE")
delegated=$(jq '.summary.delegated' "$STATUS_FILE")
converted=$(jq '.summary.converted' "$STATUS_FILE")
removed=$(jq '.summary.removed' "$STATUS_FILE")
total=$(jq '.summary.total_scripts' "$STATUS_FILE")
total_lines=$(jq '.summary.total_lines' "$STATUS_FILE")

converted_lines=$(jq '[.scripts[] | select(.status == "converted" or .status == "removed") | .lines] | add // 0' "$STATUS_FILE")
delegated_lines=$(jq '[.scripts[] | select(.status == "delegated") | .lines] | add // 0' "$STATUS_FILE")

if [ "$total_lines" -gt 0 ]; then
  pct=$(( converted_lines * 100 / total_lines ))
else
  pct=0
fi

echo "## Segkit Migration Progress"
echo ""
echo "| Metric | Value |"
echo "|--------|-------|"
echo "| Scripts converted | ${converted}/${total} |"
echo "| Lines converted | ${converted_lines}/${total_lines} (${pct}%) |"
echo ""
echo "| Platform | Shell | Delegated | Converted | Removed |"
echo "|----------|-------|-----------|-----------|---------|"

for platform in android ios react-native; do
  p_shell=$(jq "[.scripts[] | select(.platform == \"$platform\" and .status == \"shell\")] | length" "$STATUS_FILE")
  p_del=$(jq "[.scripts[] | select(.platform == \"$platform\" and .status == \"delegated\")] | length" "$STATUS_FILE")
  p_conv=$(jq "[.scripts[] | select(.platform == \"$platform\" and .status == \"converted\")] | length" "$STATUS_FILE")
  p_rem=$(jq "[.scripts[] | select(.platform == \"$platform\" and .status == \"removed\")] | length" "$STATUS_FILE")
  echo "| ${platform} | ${p_shell} | ${p_del} | ${p_conv} | ${p_rem} |"
done

echo ""
echo "| Layer | Shell | Delegated | Converted | Removed |"
echo "|-------|-------|-----------|-----------|---------|"

for layer in lib platform domain user init; do
  l_shell=$(jq "[.scripts[] | select(.layer == \"$layer\" and .status == \"shell\")] | length" "$STATUS_FILE")
  l_del=$(jq "[.scripts[] | select(.layer == \"$layer\" and .status == \"delegated\")] | length" "$STATUS_FILE")
  l_conv=$(jq "[.scripts[] | select(.layer == \"$layer\" and .status == \"converted\")] | length" "$STATUS_FILE")
  l_rem=$(jq "[.scripts[] | select(.layer == \"$layer\" and .status == \"removed\")] | length" "$STATUS_FILE")
  echo "| ${layer} | ${l_shell} | ${l_del} | ${l_conv} | ${l_rem} |"
done
