#!/usr/bin/env bash
# Shared test summary script for process-compose test suites
# Usage: test-summary.sh "Test Suite Name" "path/to/logs"

set -euo pipefail

SUITE_NAME="${1:-Test Suite}"
LOG_PATH="${2:-reports/logs}"

echo ""
echo "===================================="
echo "${SUITE_NAME} Summary"
echo "===================================="
echo ""
echo "Test Logs:"
echo "  ${LOG_PATH}"
echo ""
echo "All tests passed!"
echo "===================================="

# If TUI is enabled, sleep to keep results visible
if [ "${TEST_TUI:-false}" = "true" ] || [ "${TEST_TUI:-false}" = "1" ]; then
  echo ""
  echo "TUI mode: Waiting 30 seconds before exit (Ctrl+C to exit now)..."
  sleep 30
  echo "Exiting..."
fi
