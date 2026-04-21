#!/usr/bin/env bash
# React Native Plugin - Main CLI

set -eu

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${SCRIPT_DIR}/lib/lib.sh"

usage() {
  cat <<EOF
Usage: rn.sh <command> [options]

Commands:
  metro port [suite]       Show allocated Metro port for test suite
  metro allocate [suite]   Allocate new Metro port for test suite
  metro clean [suite]      Clean Metro state for test suite
  metro env [suite]        Export Metro environment variables

Arguments:
  suite                    Test suite name (default: "default")
                          Common values: android, ios, all

Examples:
  rn.sh metro port android
  rn.sh metro allocate ios
  rn.sh metro clean all
  rn.sh metro env android
EOF
}

case "${1:-}" in
  metro)
    suite_name="${3:-default}"
    case "${2:-}" in
      port)
        rn_get_metro_port "$suite_name"
        ;;
      allocate)
        rn_allocate_metro_port "$suite_name"
        ;;
      clean)
        rn_clean_metro "$suite_name"
        echo "✓ Cleaned Metro state for suite: $suite_name"
        ;;
      env)
        rn_export_metro_env "$suite_name"
        echo "RCT_METRO_PORT=$RCT_METRO_PORT"
        echo "METRO_PORT=$METRO_PORT"
        ;;
      *)
        usage
        exit 1
        ;;
    esac
    ;;
  *)
    usage
    exit 1
    ;;
esac
