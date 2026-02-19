#!/usr/bin/env bash
# Shared test summary script for process-compose test suites
# Usage: test-summary.sh "Test Suite Name" "path/to/logs" [marker_file]
#
# If marker_file is provided, checks for its existence to determine pass/fail.
# This ensures process-compose exits non-zero when tests fail.

set -euo pipefail

SUITE_NAME="${1:-Test Suite}"
LOG_PATH="${2:-reports/logs}"
MARKER_FILE="${3:-reports/.e2e-passed}"

echo ""
echo "===================================="
echo "${SUITE_NAME} Summary"
echo "===================================="
echo ""
echo "Test Logs:"
echo "  ${LOG_PATH}"
echo ""

if [ -f "$MARKER_FILE" ]; then
  echo "All tests passed!"
  echo "===================================="
  rm -f "$MARKER_FILE"
else
  echo "FAILED: Tests did not complete successfully"
  echo "===================================="
  # If TUI is enabled, sleep to keep results visible before failing
  if [ "${TEST_TUI:-false}" = "true" ] || [ "${TEST_TUI:-false}" = "1" ]; then
    echo ""
    echo "TUI mode: Waiting 30 seconds before exit (Ctrl+C to exit now)..."
    sleep 30
  fi
  exit 1
fi

# If TUI is enabled, sleep to keep results visible
if [ "${TEST_TUI:-false}" = "true" ] || [ "${TEST_TUI:-false}" = "1" ]; then
  echo ""
  echo "TUI mode: Waiting 30 seconds before exit (Ctrl+C to exit now)..."
  sleep 30
  echo "Exiting..."
fi
