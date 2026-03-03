#!/usr/bin/env bash
# React Native Plugin - Setup Script
# Sets up both Android and iOS environments (respecting skip flags)
# Safe to call multiple times (idempotent)

set -eu

echo "🔧 [SETUP] Setting up React Native environment..."

# Track if any setup was performed
setup_performed=0

# Setup Android (unless skipped)
if [ "${ANDROID_SKIP_SETUP:-0}" != "1" ]; then
  if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/user/setup.sh" ]; then
    bash "${ANDROID_SCRIPTS_DIR}/user/setup.sh"
    setup_performed=1
  else
    echo "⚠️  [WARN] Android plugin not found (ANDROID_SCRIPTS_DIR not set)"
  fi
else
  echo "⏭️  [SKIP] Skipping Android setup (ANDROID_SKIP_SETUP=1)"
fi

# Setup iOS (unless skipped or not on macOS)
if [ "${IOS_SKIP_SETUP:-0}" != "1" ]; then
  if [ "$(uname -s)" = "Darwin" ]; then
    if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -f "${IOS_SCRIPTS_DIR}/user/setup.sh" ]; then
      bash "${IOS_SCRIPTS_DIR}/user/setup.sh"
      setup_performed=1
    else
      echo "⚠️  [WARN] iOS plugin not found (IOS_SCRIPTS_DIR not set)"
    fi
  else
    echo "⏭️  [SKIP] Skipping iOS setup (not macOS)"
  fi
else
  echo "⏭️  [SKIP] Skipping iOS setup (IOS_SKIP_SETUP=1)"
fi

# Verify Node.js is available (required for React Native)
if ! command -v node >/dev/null 2>&1; then
  echo "⚠️  [WARN] Node.js not found (required for React Native)" >&2
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "⚠️  [WARN] npm not found (required for React Native)" >&2
fi

if [ "$setup_performed" -eq 0 ]; then
  echo "⚠️  [WARN] No platforms were set up (all skipped)"
fi

echo "✅ [OK] React Native setup complete"
