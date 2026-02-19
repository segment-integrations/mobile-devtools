#!/usr/bin/env bash
# External wrapper script to run Web tests with mobile setup skipped
# Run this from the react-native example directory: ./tests/run-web-tests.sh

set -e

cd "$(dirname "$0")/.."

# Skip Android/iOS setup for web-only testing
# Use -e flag to pass environment variable through --pure mode
exec devbox run --pure -e ANDROID_SKIP_SETUP=1 -e IOS_SKIP_SETUP=1 -e TEST_TUI="${TEST_TUI:-false}" bash -c 'process-compose -f tests/test-suite-web-e2e.yaml --no-server --tui="${TEST_TUI:-false}"'
