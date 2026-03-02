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

# Source the init setup to trigger SDK evaluation
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/init/setup.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/init/setup.sh"
fi

# Verify SDK was set up
if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
  echo "❌ Android SDK setup failed: ANDROID_SDK_ROOT not set" >&2
  exit 1
fi

if [ ! -d "${ANDROID_SDK_ROOT}" ]; then
  echo "❌ Android SDK setup failed: ANDROID_SDK_ROOT directory does not exist: ${ANDROID_SDK_ROOT}" >&2
  exit 1
fi

echo "✅ Android SDK ready: ${ANDROID_SDK_ROOT}"

# Verify essential tools are in PATH
if ! command -v adb >/dev/null 2>&1; then
  echo "⚠️  Warning: adb not in PATH" >&2
fi

if ! command -v emulator >/dev/null 2>&1; then
  echo "⚠️  Warning: emulator not in PATH" >&2
fi

echo "✅ Android setup complete"
