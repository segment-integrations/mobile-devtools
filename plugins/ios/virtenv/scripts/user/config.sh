#!/usr/bin/env sh
# iOS Plugin - Configuration Management
# See REFERENCE.md for detailed documentation

set -e

if ! (return 0 2>/dev/null); then
  echo "ERROR: config.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_CONFIG_LOADED:-}" = "1" ] && [ "${IOS_CONFIG_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_CONFIG_LOADED=1
IOS_CONFIG_LOADED_PID="$$"

# Source dependencies
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

# shellcheck disable=SC1090
. "$script_dir/lib/lib.sh"

ios_log_debug "config.sh loaded"

# ============================================================================
# Config Management Functions
# ============================================================================

# Show current configuration
ios_config_show() {
  echo "Current iOS configuration (from environment variables):"
  echo ""
  echo "Device Selection:"
  echo "  IOS_DEVICES: ${IOS_DEVICES:-(all devices)}"
  echo ""
  echo "Default Device:"
  echo "  IOS_DEFAULT_DEVICE: ${IOS_DEFAULT_DEVICE:-max}"
  echo "  IOS_DEFAULT_RUNTIME: ${IOS_DEFAULT_RUNTIME:-(auto)}"
  echo ""
  echo "Application:"
  echo "  IOS_APP_ARTIFACT: ${IOS_APP_ARTIFACT:-(auto-detect)}"
  echo "  IOS_APP_SCHEME: ${IOS_APP_SCHEME:-(auto-detect)}"
  echo "  IOS_APP_PROJECT: ${IOS_APP_PROJECT:-(auto-detect)}"
  echo ""
  echo "Build:"
  echo "  IOS_BUILD_CONFIG: ${IOS_BUILD_CONFIG:-Debug}"
  echo "  IOS_DERIVED_DATA_PATH: ${IOS_DERIVED_DATA_PATH:-.devbox/virtenv/ios/DerivedData}"
  echo ""
  echo "Runtime:"
  echo "  IOS_DOWNLOAD_RUNTIME: ${IOS_DOWNLOAD_RUNTIME:-1}"
  echo ""
  echo "Paths:"
  echo "  IOS_CONFIG_DIR: ${IOS_CONFIG_DIR:-.}"
  echo "  IOS_DEVICES_DIR: ${IOS_DEVICES_DIR:-./devbox.d/ios/devices}"
  echo "  IOS_DEVELOPER_DIR: ${IOS_DEVELOPER_DIR:-(auto)}"
  echo ""
  echo "To override values, set environment variables in your devbox.json:"
  echo '  "env": {'
  echo '    "IOS_DEVICES": "min,max",'
  echo '    "IOS_DEFAULT_DEVICE": "min"'
  echo '  }'
}
