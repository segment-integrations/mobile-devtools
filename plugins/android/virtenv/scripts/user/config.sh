#!/usr/bin/env sh
# Android Plugin - Configuration Management
# See REFERENCE.md for detailed documentation

set -e

if ! (return 0 2>/dev/null); then
  echo "ERROR: config.sh must be sourced" >&2
  exit 1
fi

if [ "${ANDROID_CONFIG_LOADED:-}" = "1" ] && [ "${ANDROID_CONFIG_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_CONFIG_LOADED=1
ANDROID_CONFIG_LOADED_PID="$$"

# Source dependencies
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  # shellcheck disable=SC1090
  . "${ANDROID_SCRIPTS_DIR}/lib/lib.sh"
fi

# ============================================================================
# Config Management Functions
# ============================================================================

# Show current configuration
android_config_show() {
  echo "Current Android configuration (from environment variables):"
  echo ""
  echo "Device Selection:"
  echo "  ANDROID_DEVICES: ${ANDROID_DEVICES:-(all devices)}"
  echo ""
  echo "Default Device:"
  echo "  ANDROID_DEFAULT_DEVICE: ${ANDROID_DEFAULT_DEVICE:-max}"
  echo ""
  echo "Application:"
  echo "  ANDROID_APP_APK: ${ANDROID_APP_APK:-(auto-detect *.apk)}"
  echo "  ANDROID_APP_ID: ${ANDROID_APP_ID:-(auto-detected from APK)}"
  echo ""
  echo "SDK Configuration:"
  echo "  ANDROID_SDK_ROOT: ${ANDROID_SDK_ROOT:-(from Nix)}"
  echo "  ANDROID_HOME: ${ANDROID_HOME:-(from Nix)}"
  echo "  ANDROID_COMPILE_SDK: ${ANDROID_COMPILE_SDK:-36}"
  echo "  ANDROID_TARGET_SDK: ${ANDROID_TARGET_SDK:-36}"
  echo "  ANDROID_BUILD_TOOLS_VERSION: ${ANDROID_BUILD_TOOLS_VERSION:-36.0.0}"
  echo "  ANDROID_CMDLINE_TOOLS_VERSION: ${ANDROID_CMDLINE_TOOLS_VERSION:-latest}"
  echo ""
  echo "System Image:"
  echo "  ANDROID_SYSTEM_IMAGE_TAG: ${ANDROID_SYSTEM_IMAGE_TAG:-google_apis}"
  echo ""
  echo "Paths:"
  echo "  ANDROID_CONFIG_DIR: ${ANDROID_CONFIG_DIR:-./devbox.d/android}"
  echo "  ANDROID_DEVICES_DIR: ${ANDROID_DEVICES_DIR:-./devbox.d/android/devices}"
  echo ""
  echo "Emulator:"
  echo "  ANDROID_EMULATOR_PURE: ${ANDROID_EMULATOR_PURE:-0}"
  echo "  ANDROID_EMULATOR_FOREGROUND: ${ANDROID_EMULATOR_FOREGROUND:-0}"
  echo ""
  echo "Advanced:"
  echo "  ANDROID_LOCAL_SDK: ${ANDROID_LOCAL_SDK:-0}"
  echo "  ANDROID_INCLUDE_NDK: ${ANDROID_INCLUDE_NDK:-0}"
  echo "  ANDROID_NDK_VERSION: ${ANDROID_NDK_VERSION:-27.2.12479018}"
  echo "  ANDROID_INCLUDE_CMAKE: ${ANDROID_INCLUDE_CMAKE:-0}"
  echo "  ANDROID_CMAKE_VERSION: ${ANDROID_CMAKE_VERSION:-3.22.1}"
  echo ""
  echo "To override values, set environment variables in your devbox.json:"
  echo '  "env": {'
  echo '    "ANDROID_DEVICES": "min,max",'
  echo '    "ANDROID_DEFAULT_DEVICE": "min",'
  echo '    "ANDROID_COMPILE_SDK": "36"'
  echo '  }'
}

# Set configuration values
# Args: key=value pairs
android_config_set() {
  echo "Configuration is now managed via environment variables." >&2
  echo "" >&2
  echo "To override configuration values, add them to your devbox.json:" >&2
  echo "" >&2
  echo '{' >&2
  echo '  "include": [' >&2
  echo '    "plugin:android"' >&2
  echo '  ],' >&2
  echo '  "env": {' >&2

  # Show the key=value pairs they wanted to set as examples
  if [ -n "${1-}" ]; then
    echo "    # Add these overrides:" >&2
    while [ "${1-}" != "" ]; do
      pair="$1"
      key="${pair%%=*}"
      value="${pair#*=}"
      echo "    \"${key}\": \"${value}\"," >&2
      shift
    done
  fi

  echo '  }' >&2
  echo '}' >&2
  echo "" >&2
  echo "After updating devbox.json, run 'devbox shell' to apply changes." >&2
  return 1
}

# Reset configuration to defaults
android_config_reset() {
  echo "Configuration is now managed via environment variables." >&2
  echo "" >&2
  echo "To reset to defaults, remove any ANDROID_* environment variable" >&2
  echo "overrides from your devbox.json env section." >&2
  echo "" >&2
  echo "Plugin defaults are defined in the android plugin.json file." >&2
  echo "Run 'android.sh config show' to see current values." >&2
  return 1
}
