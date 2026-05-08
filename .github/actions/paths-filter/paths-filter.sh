#!/usr/bin/env bash
# Detect which paths changed between a base ref and HEAD.
# Writes each filter key as a GITHUB_OUTPUT with value 'true' or 'false'.
#
# Required env:
#   FILTER_DEFINITIONS - YAML-style filter block (key: \n  - 'pattern')
#   GITHUB_OUTPUT      - set by GitHub Actions runner
#
# Optional env:
#   FILTER_BASE - explicit base ref to diff against
#
# Usage in a workflow step:
#   - name: Detect changes
#     id: filter
#     env:
#       FILTER_DEFINITIONS: |
#         android:
#           - '^plugins/android/'
#           - '^examples/android/'
#         ios:
#           - '^plugins/ios/'
#     run: bash .github/actions/paths-filter/paths-filter.sh
set -euo pipefail

# Determine base commit
if [ -n "${FILTER_BASE:-}" ]; then
  BASE="$FILTER_BASE"
elif [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
  BASE=$(jq -r '.pull_request.base.sha' "$GITHUB_EVENT_PATH")
else
  BASE="HEAD~1"
fi

# Get list of changed files
CHANGED_FILES=$(git diff --name-only "$BASE"...HEAD 2>/dev/null || git diff --name-only "$BASE" HEAD)

if [ -z "$CHANGED_FILES" ]; then
  echo "No changed files detected"
else
  echo "Changed files (first 50):"
  echo "$CHANGED_FILES" | head -50
fi

# Parse filters and collect results
declare -A RESULTS
CURRENT_KEY=""

while IFS= read -r line; do
  [ -z "$(echo "$line" | tr -d '[:space:]')" ] && continue

  if echo "$line" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_-]*:'; then
    CURRENT_KEY=$(echo "$line" | sed 's/:.*$//' | tr -d '[:space:]')
    RESULTS["$CURRENT_KEY"]="false"
    continue
  fi

  if [ -n "$CURRENT_KEY" ] && echo "$line" | grep -qE '^\s*-'; then
    PATTERN=$(echo "$line" | sed "s/^[[:space:]]*-[[:space:]]*//;s/^['\"]//;s/['\"]$//")
    PATTERN=$(echo "$PATTERN" | tr -d '[:space:]')
    [ -z "$PATTERN" ] && continue

    if [ -n "$CHANGED_FILES" ] && echo "$CHANGED_FILES" | grep -qE "$PATTERN"; then
      RESULTS["$CURRENT_KEY"]="true"
    fi
  fi
done <<< "$FILTER_DEFINITIONS"

# Write outputs
JSON="{"
FIRST=true
for key in "${!RESULTS[@]}"; do
  echo "${key}=${RESULTS[$key]}" >> "$GITHUB_OUTPUT"
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    JSON="$JSON,"
  fi
  JSON="$JSON\"$key\":\"${RESULTS[$key]}\""
done
JSON="$JSON}"

echo "Filter results: $JSON"
