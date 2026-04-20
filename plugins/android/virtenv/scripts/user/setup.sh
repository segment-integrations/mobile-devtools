#!/usr/bin/env bash
# Android Plugin - Setup Script
# Pre-evaluates and caches Android SDK for fast subsequent operations
# Safe to call multiple times (idempotent)

set -eu

# Skip if ANDROID_SKIP_SETUP=1
if [ "${ANDROID_SKIP_SETUP:-0}" = "1" ]; then
  echo "⏭️  [SKIP] Skipping Android setup (ANDROID_SKIP_SETUP=1)"
  exit 0
fi

echo "🔧 [SETUP] Setting up Android environment..."

# If ANDROID_SDK_ROOT is already set and valid (e.g. from devbox init_hook),
# skip re-evaluation. This avoids redundant Nix flake builds in subprocesses.
if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "${ANDROID_SDK_ROOT}" ]; then
  echo "✅ [OK] Android SDK: ${ANDROID_SDK_ROOT}"
else
  # SDK not yet resolved. Try evaluating the Nix flake directly with
  # visible error output (init/setup.sh suppresses errors for non-blocking init).
  flake_root="${ANDROID_SDK_FLAKE_PATH:-}"
  if [ -z "$flake_root" ]; then
    if [ -n "${ANDROID_RUNTIME_DIR:-}" ] && [ -d "${ANDROID_RUNTIME_DIR}" ]; then
      flake_root="${ANDROID_RUNTIME_DIR}"
    elif [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -d "${ANDROID_SCRIPTS_DIR}" ]; then
      flake_root="$(dirname "${ANDROID_SCRIPTS_DIR}")"
    fi
  fi

  flake_output="${ANDROID_SDK_FLAKE_OUTPUT:-android-sdk}"

  if [ -n "$flake_root" ] && command -v nix >/dev/null 2>&1; then
    echo "🔍 [INFO] Evaluating Android SDK from Nix flake..."
    echo "   This may take a few minutes on first run"

    sdk_out=$(
      nix --extra-experimental-features 'nix-command flakes' \
        build "path:${flake_root}#${flake_output}" --no-link --print-out-paths 2>&1
    ) || true

    # Check if we got a valid store path
    if [ -n "${sdk_out:-}" ] && echo "$sdk_out" | grep -q "^/nix/store/"; then
      sdk_path=$(echo "$sdk_out" | grep "^/nix/store/" | head -1)
      if [ -d "$sdk_path/libexec/android-sdk" ]; then
        ANDROID_SDK_ROOT="$sdk_path/libexec/android-sdk"
        export ANDROID_SDK_ROOT
      fi
    fi

    # Show nix build output if SDK resolution failed (helps debug CI)
    if [ -z "${ANDROID_SDK_ROOT:-}" ] && [ -n "${sdk_out:-}" ]; then
      echo "⚠️  [WARN] Nix build output:" >&2
      echo "$sdk_out" | tail -20 >&2
    fi
  fi

  # Fallback: try sourcing init/setup.sh which has additional detection methods
  if [ -z "${ANDROID_SDK_ROOT:-}" ] || [ ! -d "${ANDROID_SDK_ROOT:-/nonexistent}" ]; then
    if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/init/setup.sh" ]; then
      . "${ANDROID_SCRIPTS_DIR}/init/setup.sh"
    fi
  fi

  # Fallback: detect from adb in PATH
  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    adb_path="$(command -v adb 2>/dev/null || true)"
    if [ -n "$adb_path" ]; then
      sdk_candidate="$(cd "$(dirname "$adb_path")/.." && pwd)"
      if [ -d "$sdk_candidate/platform-tools" ]; then
        ANDROID_SDK_ROOT="$sdk_candidate"
        export ANDROID_SDK_ROOT ANDROID_HOME="$ANDROID_SDK_ROOT"
      fi
    fi
  fi

  # Final verification
  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    echo "❌ [ERROR] Android SDK setup failed: ANDROID_SDK_ROOT not set" >&2
    echo "   Ensure the Nix flake at ${flake_root:-unknown} evaluates correctly." >&2
    exit 1
  fi

  if [ ! -d "${ANDROID_SDK_ROOT}" ]; then
    echo "❌ [ERROR] Android SDK setup failed: ANDROID_SDK_ROOT directory does not exist: ${ANDROID_SDK_ROOT}" >&2
    exit 1
  fi

  echo "✅ [OK] Android SDK: ${ANDROID_SDK_ROOT}"
fi

# Write SDK root to shared state file (for process-compose sibling processes)
if [ -n "${ANDROID_RUNTIME_DIR:-}" ]; then
  mkdir -p "${ANDROID_RUNTIME_DIR}/.state"
  echo "${ANDROID_SDK_ROOT}" > "${ANDROID_RUNTIME_DIR}/.state/sdk_root"
fi

# Verify essential tools are in PATH
if ! command -v adb >/dev/null 2>&1; then
  echo "⚠️  [WARN] adb not in PATH" >&2
fi

if ! command -v emulator >/dev/null 2>&1; then
  echo "⚠️  [WARN] emulator not in PATH" >&2
fi

# Check for configuration drift (android.lock out of sync with env vars)
config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
android_lock="${config_dir}/android.lock"

if [ -f "$android_lock" ] && command -v jq >/dev/null 2>&1; then
  drift_detected=false
  drift_messages=""

  # Compare each env var with android.lock
  for var in ANDROID_BUILD_TOOLS_VERSION ANDROID_CMDLINE_TOOLS_VERSION ANDROID_COMPILE_SDK ANDROID_TARGET_SDK ANDROID_SYSTEM_IMAGE_TAG ANDROID_INCLUDE_NDK ANDROID_NDK_VERSION ANDROID_INCLUDE_CMAKE ANDROID_CMAKE_VERSION; do
    env_val="${!var:-}"
    lock_val="$(jq -r ".${var} // empty" "$android_lock" 2>/dev/null || echo "")"

    # Normalize boolean values for comparison
    if [ "$var" = "ANDROID_INCLUDE_NDK" ] || [ "$var" = "ANDROID_INCLUDE_CMAKE" ]; then
      case "$env_val" in
        1|true|TRUE|yes|YES|on|ON) env_val="true" ;;
        *) env_val="false" ;;
      esac
    fi

    # Skip if lock value is empty (field doesn't exist in lock)
    [ -z "$lock_val" ] && continue

    if [ "$env_val" != "$lock_val" ]; then
      drift_detected=true
      drift_messages="${drift_messages}  ${var}: \"${env_val}\" (env) vs \"${lock_val}\" (lock)\n"
    fi
  done

  if [ "$drift_detected" = true ]; then
    echo "" >&2
    echo "⚠️  WARNING: Android configuration has changed but lock file is outdated." >&2
    echo "" >&2
    echo "Environment variables don't match android.lock:" >&2
    printf "$drift_messages" >&2
    echo "" >&2
    echo "To apply changes:" >&2
    echo "  devbox run android:sync" >&2
    echo "" >&2
    echo "To revert changes:" >&2
    echo "  Edit devbox.json to match the lock file" >&2
    echo "" >&2
  fi
fi

echo "✅ [OK] Android setup complete"
