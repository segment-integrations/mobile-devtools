#!/usr/bin/env bash
# Android Plugin - Setup Script
# Pre-evaluates and caches Android SDK for fast subsequent operations
# Safe to call multiple times (idempotent)

set -eu

# Skip if ANDROID_SKIP_SETUP=1
if [ "${ANDROID_SKIP_SETUP:-0}" = "1" ]; then
  echo "⏭️  Skipping Android setup (ANDROID_SKIP_SETUP=1)"
  exit 0
fi

echo "🔧 Setting up Android environment..."

# If ANDROID_SDK_ROOT is already set and valid (e.g. from devbox init_hook),
# skip re-evaluation. This avoids redundant Nix flake builds in subprocesses.
if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "${ANDROID_SDK_ROOT}" ]; then
  echo "✅ Android SDK ready: ${ANDROID_SDK_ROOT}"
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
    echo "🔍 Evaluating Android SDK from Nix flake..."
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
      echo "⚠️  Nix build output:" >&2
      echo "$sdk_out" | tail -20 >&2
    fi
  fi

  # Fallback: try sourcing init/setup.sh which has additional detection methods
  if [ -z "${ANDROID_SDK_ROOT:-}" ] || [ ! -d "${ANDROID_SDK_ROOT:-/nonexistent}" ]; then
    if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/init/setup.sh" ]; then
      . "${ANDROID_SCRIPTS_DIR}/init/setup.sh"
    fi
  fi

  # Final verification
  if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    echo "❌ Android SDK setup failed: ANDROID_SDK_ROOT not set" >&2
    echo "   Ensure the Nix flake at ${flake_root:-unknown} evaluates correctly." >&2
    exit 1
  fi

  if [ ! -d "${ANDROID_SDK_ROOT}" ]; then
    echo "❌ Android SDK setup failed: ANDROID_SDK_ROOT directory does not exist: ${ANDROID_SDK_ROOT}" >&2
    exit 1
  fi

  echo "✅ Android SDK ready: ${ANDROID_SDK_ROOT}"
fi

# Verify essential tools are in PATH
if ! command -v adb >/dev/null 2>&1; then
  echo "⚠️  Warning: adb not in PATH" >&2
fi

if ! command -v emulator >/dev/null 2>&1; then
  echo "⚠️  Warning: emulator not in PATH" >&2
fi

echo "✅ Android setup complete"
