#!/usr/bin/env bash
# External wrapper script to run Android tests with iOS setup skipped
# Run this from the react-native example directory: ./tests/run-android-tests.sh

set -e

cd "$(dirname "$0")/.."

# Skip iOS setup for Android-only testing
# Use -e flag to pass environment variable through --pure mode
exec devbox run --pure -e IOS_SKIP_SETUP=1 -e TEST_TUI="${TEST_TUI:-false}" bash -c 'process-compose -f tests/test-suite-android-e2e.yaml --no-server --tui="${TEST_TUI:-false}"'
