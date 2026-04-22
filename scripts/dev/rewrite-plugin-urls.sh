#!/usr/bin/env bash
# Rewrite plugin URLs in devbox.json files
# Usage: rewrite-plugin-urls.sh [--to-local|--to-github] [directory]
#
# --to-local:  Rewrite github: URLs to path: (for local testing)
# --to-github: Rewrite path: URLs to github: (restore public format)
# directory:   Directory to search (default: examples/)

set -euo pipefail

mode="${1:---to-local}"
search_dir="${2:-examples}"

if [ ! -d "$search_dir" ]; then
  echo "ERROR: Directory not found: $search_dir" >&2
  exit 1
fi

case "$mode" in
  --to-local)
    echo "Rewriting plugin URLs to local paths..."

    # Rewrite examples/ devbox.json files
    if [ -d "$search_dir" ]; then
      echo "  Processing examples in $search_dir..."
      find "$search_dir" -name "devbox.json" -type f | while read -r file; do
        if grep -q "github:segment-integrations/mobile-devtools" "$file"; then
          echo "    Rewriting: $file"

          # Backup original
          cp "$file" "$file.bak"

          # Rewrite URLs using jq (cross-platform, JSON-safe)
          jq '.include = (.include | map(
            if . == "github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main"
            then "path:../../plugins/android/plugin.json"
            elif . == "github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"
            then "path:../../plugins/ios/plugin.json"
            elif . == "github:segment-integrations/mobile-devtools?dir=plugins/react-native&ref=main"
            then "path:../../plugins/react-native/plugin.json"
            else . end
          ))' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        fi
      done
    fi

    # Rewrite plugins/ plugin.json files (react-native includes android/ios)
    if [ -f "plugins/react-native/plugin.json" ]; then
      echo "  Processing react-native plugin..."
      if grep -q "github:segment-integrations/mobile-devtools" "plugins/react-native/plugin.json"; then
        echo "    Rewriting: plugins/react-native/plugin.json"

        # Backup original
        cp "plugins/react-native/plugin.json" "plugins/react-native/plugin.json.bak"

        # Rewrite URLs to relative paths from react-native plugin
        jq '.include = (.include | map(
          if . == "github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main"
          then "path:../android/plugin.json"
          elif . == "github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"
          then "path:../ios/plugin.json"
          else . end
        ))' "plugins/react-native/plugin.json" > "plugins/react-native/plugin.json.tmp" \
          && mv "plugins/react-native/plugin.json.tmp" "plugins/react-native/plugin.json"
      fi
    fi

    echo "✓ Rewrote plugin URLs to local paths"
    ;;

  --to-github)
    echo "Restoring plugin URLs to GitHub format..."

    # Restore examples/ devbox.json files
    if [ -d "$search_dir" ]; then
      echo "  Processing examples in $search_dir..."
      find "$search_dir" -name "devbox.json" -type f | while read -r file; do
        if [ -f "$file.bak" ]; then
          echo "    Restoring from backup: $file"
          mv "$file.bak" "$file"
        elif grep -q "path:.*plugins/.*/plugin.json" "$file"; then
          echo "    Rewriting: $file"

          # Rewrite URLs using jq (cross-platform, JSON-safe)
          jq '.include = (.include | map(
            if . == "path:../../plugins/android/plugin.json"
            then "github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main"
            elif . == "path:../../plugins/ios/plugin.json"
            then "github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"
            elif . == "path:../../plugins/react-native/plugin.json"
            then "github:segment-integrations/mobile-devtools?dir=plugins/react-native&ref=main"
            else . end
          ))' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        fi
      done
      # Clean up any remaining backups
      find "$search_dir" -name "devbox.json.bak" -type f -delete
    fi

    # Restore plugins/ plugin.json files
    if [ -f "plugins/react-native/plugin.json.bak" ]; then
      echo "  Processing react-native plugin..."
      echo "    Restoring from backup: plugins/react-native/plugin.json"
      mv "plugins/react-native/plugin.json.bak" "plugins/react-native/plugin.json"
    elif [ -f "plugins/react-native/plugin.json" ] && grep -q "path:../android/plugin.json\|path:../ios/plugin.json" "plugins/react-native/plugin.json"; then
      echo "  Processing react-native plugin..."
      echo "    Rewriting: plugins/react-native/plugin.json"

      # Rewrite URLs back to GitHub format
      jq '.include = (.include | map(
        if . == "path:../android/plugin.json"
        then "github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main"
        elif . == "path:../ios/plugin.json"
        then "github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"
        else . end
      ))' "plugins/react-native/plugin.json" > "plugins/react-native/plugin.json.tmp" \
        && mv "plugins/react-native/plugin.json.tmp" "plugins/react-native/plugin.json"
    fi

    echo "✓ Restored plugin URLs to GitHub format"
    ;;

  *)
    echo "ERROR: Unknown mode: $mode" >&2
    echo "Usage: $0 [--to-local|--to-github] [directory]" >&2
    exit 1
    ;;
esac
