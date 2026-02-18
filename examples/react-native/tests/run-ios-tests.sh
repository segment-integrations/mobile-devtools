#!/usr/bin/env bash
# External wrapper script to run iOS tests with Android SDK evaluation skipped
# Run this from the react-native example directory: ./tests/run-android-tests.sh

set -e

cd "$(dirname "$0")/.."

# Skip Android SDK downloads/evaluation for iOS-only testing
# Use -e flag to pass environment variable through --pure mode
exec devbox run --pure -e ANDROID_SKIP_SETUP=1 -e TEST_TUI="${TEST_TUI:-false}" bash -c 'process-compose -f tests/test-suite-ios-e2e.yaml --no-server --tui="${TEST_TUI:-false}"'
