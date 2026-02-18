#!/usr/bin/env bash
# Sync example projects with latest plugin sources
# Deletes .devbox and regenerates from plugin sources via devbox install

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "Syncing example projects with latest plugin sources..."
echo ""

for example in android ios react-native; do
  example_dir="$REPO_ROOT/examples/$example"
  if [ -d "$example_dir" ]; then
    echo "  $example: removing .devbox and reinstalling..."
    (cd "$example_dir" && rm -rf .devbox && devbox install)
    echo "  ✓ $example synced"
  fi
done

echo ""
echo "✓ All examples synced"
