#!/usr/bin/env bash
# Android Plugin - Core SDK and Environment Setup
# Extracted from env.sh to eliminate circular dependencies

set -e

if ! (return 0 2>/dev/null); then
  echo "ERROR: core.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_CORE_LOADED:-}" = "1" ] && [ "${ANDROID_CORE_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_CORE_LOADED=1
ANDROID_CORE_LOADED_PID="$$"

# Source dependencies
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/lib/lib.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/lib/lib.sh"
fi

# ============================================================================
# Debug Utilities
# ============================================================================

android_debug_enabled() {
  [ "${ANDROID_DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "1" ]
}

android_debug_log() {
  if android_debug_enabled; then
    printf '%s\n' "DEBUG: $*" >&2
  fi
}

android_debug_log_script() {
  if android_debug_enabled; then
    if (return 0 2>/dev/null); then
      context="sourced"
    else
      context="run"
    fi
    android_debug_log "$1 ($context)"
  fi
}

android_debug_dump_vars() {
  if android_debug_enabled; then
    for var in "$@"; do
      value="$(eval "printf '%s' \"\${$var-}\"")"
      printf 'DEBUG: %s=%s\n' "$var" "$value"
    done
  fi
}

# ============================================================================
# SDK Resolution
# ============================================================================

resolve_flake_sdk_root() {
  output="$1"
  [ -n "${ANDROID_DEBUG_SETUP:-}" ] && echo "[CORE-$$] resolve_flake_sdk_root: output=$output" >&2

  if ! command -v nix >/dev/null 2>&1; then
    [ -n "${ANDROID_DEBUG_SETUP:-}" ] && echo "[CORE-$$] nix command not found" >&2
    return 1
  fi

  root="${ANDROID_SDK_FLAKE_PATH:-}"
  if [ -z "$root" ]; then
    # Flake is in the config directory (devbox.d/) where device configs live
    if [ -n "${ANDROID_CONFIG_DIR:-}" ] && [ -d "${ANDROID_CONFIG_DIR}" ]; then
      root="${ANDROID_CONFIG_DIR}"
    else
      echo "[ERROR] Failed to resolve flake SDK root directory" >&2
      echo "        ANDROID_CONFIG_DIR not set or directory does not exist" >&2
      return 1
    fi
    ANDROID_SDK_FLAKE_PATH="$root"
    export ANDROID_SDK_FLAKE_PATH
  fi

  [ -n "${ANDROID_DEBUG_SETUP:-}" ] && echo "[CORE-$$] Flake root: $root" >&2

  if android_debug_enabled; then
    android_debug_log "Android SDK flake path: ${ANDROID_SDK_FLAKE_PATH:-$root}"
  fi

  # Show progress message (only once per session)
  if [ -z "${ANDROID_NIX_EVAL_SHOWN:-}" ]; then
    echo "🔍 [INFO] Evaluating Android SDK from Nix flake..." >&2
    echo "   This may take a few minutes on first run" >&2
    export ANDROID_NIX_EVAL_SHOWN=1
  fi

  # Build the SDK to ensure it's in the Nix store
  # Capture stderr so failures are visible instead of silently swallowed
  [ -n "${ANDROID_DEBUG_SETUP:-}" ] && echo "[CORE-$$] Building SDK: path:${root}#${output}" >&2
  _nix_stderr=""
  _nix_stderr_file=$(mktemp "${TMPDIR:-/tmp}/android-nix-build-XXXXXX.stderr")
  sdk_out=$(
    nix --extra-experimental-features 'nix-command flakes' \
      build "path:${root}#${output}" --no-link --print-out-paths --show-trace 2>"$_nix_stderr_file"
  ) || true
  _nix_stderr=""
  if [ -f "$_nix_stderr_file" ]; then
    _nix_stderr=$(cat "$_nix_stderr_file" 2>/dev/null || true)
  fi
  [ -n "${ANDROID_DEBUG_SETUP:-}" ] && echo "[CORE-$$] nix build returned: ${sdk_out:-(empty)}" >&2

  if [ -n "${sdk_out:-}" ] && [ -d "$sdk_out/libexec/android-sdk" ]; then
    rm -f "$_nix_stderr_file"
    printf '%s\n' "$sdk_out/libexec/android-sdk"
    return 0
  fi

  # Nix build failed - show the error so it's not a silent failure
  if [ -n "$_nix_stderr" ]; then
    # Check for hash mismatch or dependency failures (often caused by hash mismatches)
    if echo "$_nix_stderr" | grep -qE "(hash mismatch in fixed-output derivation|Cannot build.*android-sdk.*Reason: 1 dependency failed)"; then
      echo "" >&2
      echo "⚠️  Android SDK hash mismatch detected" >&2
      echo "" >&2
      echo "Google updated files on their servers without changing version numbers." >&2
      echo "Fixing automatically..." >&2
      echo "" >&2

      # Try to automatically fix the hash mismatch
      if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/domain/hash-fix.sh" ]; then
        if bash "${ANDROID_SCRIPTS_DIR}/domain/hash-fix.sh" auto "$_nix_stderr_file" 2>&1; then
          echo "" >&2
          echo "✅ Hash mismatch fixed!" >&2
          echo "" >&2
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
          echo "1. Run 'devbox shell' again to rebuild with the fix" >&2
          echo "2. Commit hash-overrides.json to preserve reproducibility:" >&2
          echo "   git add devbox.d/*/hash-overrides.json" >&2
          echo "   git commit -m \"fix(android): add SDK hash override\"" >&2
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
          echo "" >&2
        else
          echo "" >&2
          echo "⚠️  Automatic fix failed. Manual workarounds:" >&2
          echo "" >&2
          echo "1. Use Android Studio SDK:" >&2
          echo "   Add to devbox.json:" >&2
          echo '     "env": {' >&2
          echo '       "ANDROID_LOCAL_SDK": "1",' >&2
          echo '       "ANDROID_SDK_ROOT": "/Users/YOU/Library/Android/sdk"' >&2
          echo '     }' >&2
          echo "" >&2
          echo "2. Update nixpkgs: cd devbox.d/*/android/ && nix flake update" >&2
          echo "" >&2
          echo "3. Run on Linux x86_64 where SDK builds more reliably" >&2
          echo "" >&2
          echo "See: https://github.com/NixOS/nixpkgs/issues?q=android+hash+mismatch" >&2
          echo "" >&2
        fi
      else
        echo "⚠️  Hash fix script not found. Manual fix:" >&2
        echo "   devbox run android:hash-fix" >&2
        echo "" >&2
      fi
      # Manual cleanup after hash-fix
      rm -f "$_nix_stderr_file" 2>/dev/null || true
    fi
    echo "WARNING: Android SDK Nix flake evaluation failed:" >&2
    # Show last 15 lines of stderr (skip noisy download progress)
    printf '%s\n' "$_nix_stderr" | tail -15 >&2
  elif [ -z "${sdk_out:-}" ]; then
    echo "WARNING: Android SDK Nix flake evaluation returned empty output" >&2
  fi
  rm -f "$_nix_stderr_file"
  return 1
}

detect_sdk_root_from_sdkmanager() {
  sm="$(command -v sdkmanager 2>/dev/null || true)"
  if [ -z "$sm" ]; then
    return 1
  fi
  if command -v readlink >/dev/null 2>&1; then
    sm="$(readlink "$sm" 2>/dev/null || printf '%s' "$sm")"
  fi
  sm_dir="$(cd "$(dirname "$sm")" && pwd)"
  candidates="${sm_dir}/.. ${sm_dir}/../share/android-sdk ${sm_dir}/../libexec/android-sdk ${sm_dir}/../.."
  for c in $candidates; do
    if [ -d "$c/platform-tools" ] || [ -d "$c/platforms" ] || [ -d "$c/system-images" ]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

detect_sdk_root_from_tools() {
  for tool in adb emulator; do
    bin_path="$(command -v "$tool" 2>/dev/null || true)"
    if [ -z "$bin_path" ]; then
      continue
    fi
    if command -v readlink >/dev/null 2>&1; then
      bin_path="$(readlink "$bin_path" 2>/dev/null || printf '%s' "$bin_path")"
    fi
    bin_dir="$(cd "$(dirname "$bin_path")" && pwd)"
    candidates="${bin_dir}/.. ${bin_dir}/../.."
    for c in $candidates; do
      if [ -d "$c/platform-tools" ] || [ -d "$c/emulator" ] || [ -d "$c/system-images" ]; then
        printf '%s\n' "$c"
        return 0
      fi
    done
  done
  return 1
}

# ============================================================================
# Environment Setup
# ============================================================================

android_setup_sdk_environment() {
  prefer_local="${ANDROID_LOCAL_SDK:-}"
  case "$prefer_local" in
    1 | true | TRUE | yes | YES | on | ON)
      prefer_local=1
      ;;
    *)
      prefer_local=""
      ;;
  esac

  if [ -z "${ANDROID_SDK_FLAKE_OUTPUT:-}" ]; then
    ANDROID_SDK_FLAKE_OUTPUT="android-sdk"
    export ANDROID_SDK_FLAKE_OUTPUT
  fi

  if [ -n "$prefer_local" ]; then
    if [ -z "${ANDROID_SDK_ROOT:-}" ] && [ -n "${ANDROID_HOME:-}" ]; then
      ANDROID_SDK_ROOT="$ANDROID_HOME"
    fi
    if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
      detected_root="$(detect_sdk_root_from_sdkmanager 2>/dev/null || true)"
      if [ -n "$detected_root" ]; then
        ANDROID_SDK_ROOT="$detected_root"
      fi
    fi
  else
    resolved_root="$(resolve_flake_sdk_root "$ANDROID_SDK_FLAKE_OUTPUT" || true)"
    if [ -n "$resolved_root" ]; then
      ANDROID_SDK_ROOT="$resolved_root"
      if [ -n "${ANDROID_NIX_EVAL_SHOWN:-}" ]; then
        echo "✓ Android SDK resolved from Nix flake" >&2
      fi
    fi
  fi

  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    detected_root="$(detect_sdk_root_from_sdkmanager 2>/dev/null || true)"
    if [ -n "$detected_root" ]; then
      ANDROID_SDK_ROOT="$detected_root"
    fi
  fi

  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    detected_root="$(detect_sdk_root_from_tools 2>/dev/null || true)"
    if [ -n "$detected_root" ]; then
      ANDROID_SDK_ROOT="$detected_root"
    fi
  fi

  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    # Warn but don't fail - SDK will be checked when actually needed (e.g., emulator start)
    # Don't warn during device eval
    if [ -z "${ANDROID_DEVICES_EVAL:-}" ]; then
      echo "WARNING: ANDROID_SDK_ROOT could not be resolved. Some commands may fail." >&2
      if ! command -v nix >/dev/null 2>&1 && [ "${ANDROID_LOCAL_SDK:-0}" = "0" ]; then
        echo "         Ensure Nix is available or set ANDROID_LOCAL_SDK=1 with a local Android SDK." >&2
      fi
    fi
    # Set empty value to avoid unbound variable errors
    ANDROID_SDK_ROOT=""
  fi

  ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  export ANDROID_SDK_ROOT ANDROID_HOME
  export ANDROID_BUILD_TOOLS_VERSION

  state_home="${ANDROID_USER_HOME:-}"
  if [ -z "$state_home" ]; then
    state_home="${ANDROID_SDK_HOME:-}"
  fi
  if [ -z "$state_home" ]; then
    state_home="${ANDROID_SDK_ROOT:-}"
  fi
  if [ -z "$state_home" ]; then
    # Use virtenv as fallback for state home
    state_home="${ANDROID_EMULATOR_HOME:-}"
  fi
  if [ -z "$state_home" ]; then
    echo "WARNING: ANDROID_USER_HOME could not be determined. AVDs may not be project-local." >&2
    # Continue anyway - some commands don't need AVDs
  fi

  ANDROID_USER_HOME="$state_home"
  ANDROID_SDK_HOME="$state_home"
  ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$state_home/avd}"
  ANDROID_EMULATOR_HOME="${ANDROID_EMULATOR_HOME:-$state_home}"

  unset ANDROID_PREFS_ROOT

  export ANDROID_USER_HOME ANDROID_AVD_HOME ANDROID_EMULATOR_HOME

  mkdir -p "$state_home" "$ANDROID_AVD_HOME" >/dev/null 2>&1 || true

  if android_debug_enabled; then
    android_debug_dump_vars \
      ANDROID_PLUGIN_CONFIG \
      ANDROID_SDK_FLAKE_PATH \
      ANDROID_SDK_FLAKE_OUTPUT \
      ANDROID_LOCAL_SDK \
      ANDROID_SDK_ROOT \
      ANDROID_HOME \
      ANDROID_SDK_HOME \
      ANDROID_USER_HOME \
      ANDROID_AVD_HOME \
      ANDROID_EMULATOR_HOME \
      ANDROID_CONFIG_DIR \
      ANDROID_DEVICES_DIR \
      ANDROID_DEFAULT_DEVICE \
      ANDROID_COMPILE_SDK \
      ANDROID_TARGET_SDK \
      ANDROID_BUILD_TOOLS_VERSION \
      ANDROID_CMDLINE_TOOLS_VERSION
  fi
}

# ============================================================================
# PATH Setup
# ============================================================================

android_setup_path() {
  if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    cmdline_tools_bin=""
    if [ -d "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin" ]; then
      cmdline_tools_bin="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
    else
      cmdline_tools_dir=$(find "$ANDROID_SDK_ROOT/cmdline-tools" -maxdepth 1 -mindepth 1 -type d -not -name latest 2>/dev/null | sort -V | tail -n 1)
      if [ -n "${cmdline_tools_dir:-}" ] && [ -d "$cmdline_tools_dir/bin" ]; then
        cmdline_tools_bin="$cmdline_tools_dir/bin"
      fi
    fi

    new_path="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/platform-tools"
    if [ -n "${cmdline_tools_bin:-}" ]; then
      new_path="$new_path:$cmdline_tools_bin"
    fi
    PATH="$new_path:$ANDROID_SDK_ROOT/tools/bin:$PATH"
    export PATH
  fi

  # Add user-facing CLI scripts to PATH
  if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -d "${ANDROID_SCRIPTS_DIR}" ]; then
    # Make all scripts executable
    find "${ANDROID_SCRIPTS_DIR}" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    # Add user/ directory to PATH (contains android.sh, devices.sh)
    if [ -d "${ANDROID_SCRIPTS_DIR}/user" ]; then
      PATH="${ANDROID_SCRIPTS_DIR}/user:$PATH"
      export PATH
    fi
  fi
}

# ============================================================================
# Summary Display
# ============================================================================

android_show_summary() {
  android_sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  android_sdk_version="${ANDROID_BUILD_TOOLS_VERSION:-${ANDROID_CMDLINE_TOOLS_VERSION:-30.0.3}}"
  devices_dir="${ANDROID_DEVICES_DIR:-${ANDROID_CONFIG_DIR:-}/devices}"
  default_device="${ANDROID_DEFAULT_DEVICE:-}"

  if android_debug_enabled; then
    android_debug_dump_vars \
      ANDROID_SDK_ROOT \
      ANDROID_HOME \
      ANDROID_LOCAL_SDK \
      ANDROID_SDK_FLAKE_OUTPUT \
      ANDROID_SYSTEM_IMAGE_TAG \
      ANDROID_BUILD_TOOLS_VERSION \
      ANDROID_CMDLINE_TOOLS_VERSION \
      ANDROID_DEFAULT_DEVICE \
      ANDROID_DEVICES_DIR
  fi

  echo "Resolved Android SDK"
  echo "  ANDROID_SDK_ROOT: ${android_sdk_root:-not set}"
  echo "  ANDROID_BUILD_TOOLS_VERSION: ${android_sdk_version:-30.0.3}"
  echo "  ANDROID_DEVICES_DIR: ${devices_dir:-not set}"
  if [ -n "$default_device" ]; then
    echo "  ANDROID_DEFAULT_DEVICE: ${default_device}"
  fi
  echo "  Tip: use a local SDK with ANDROID_LOCAL_SDK=1 ANDROID_SDK_ROOT=/path/to/sdk (or ANDROID_HOME)."
}

android_debug_log_script "core.sh"
