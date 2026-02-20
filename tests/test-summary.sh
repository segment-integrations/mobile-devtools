#!/usr/bin/env bash
# Test Suite Summary - ASCII terminal output + markdown report
# Aggregates reports/results/*.json written by test_summary()
set -euo pipefail

# Configuration
REPORTS_DIR="${REPORTS_DIR:-reports}"
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-$REPORTS_DIR/results}"
TEST_LOGS_DIR="${TEST_LOGS_DIR:-$REPORTS_DIR/logs}"

# Setup logging to file
mkdir -p "$TEST_LOGS_DIR"
LOG_FILE="$TEST_LOGS_DIR/summary.txt"
exec > >(tee "$LOG_FILE")
exec 2>&1

# Source framework for _regenerate_summary
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export REPO_ROOT
. "$REPO_ROOT/plugins/tests/test-framework.sh"

# Regenerate reports/summary.md from all per-suite JSONs
_regenerate_summary "$TEST_RESULTS_DIR"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================================
# Collect results for ASCII output
# ============================================================================

_total_passed=0
_total_failed=0
_suite_count=0
_any_failure=0

_suite_names=()
_suite_passed=()
_suite_failed=()
_suite_totals=()
_suite_times=()

for result_file in $(ls "$TEST_RESULTS_DIR"/*.json 2>/dev/null | sort); do
  [ -f "$result_file" ] || continue
  name=$(jq -r '.suite // "unknown"' "$result_file" 2>/dev/null)
  p=$(jq -r '.passed // 0' "$result_file" 2>/dev/null)
  f=$(jq -r '.failed // 0' "$result_file" 2>/dev/null)
  t=$(jq -r '.total // 0' "$result_file" 2>/dev/null)
  ts=$(jq -r '.timestamp // ""' "$result_file" 2>/dev/null)

  _suite_names+=("$name")
  _suite_passed+=("$p")
  _suite_failed+=("$f")
  _suite_totals+=("$t")
  _suite_times+=("$ts")

  _total_passed=$((_total_passed + p))
  _total_failed=$((_total_failed + f))
  _suite_count=$((_suite_count + 1))
  if [ "$f" -gt 0 ]; then _any_failure=1; fi
done

_grand_total=$((_total_passed + _total_failed))

# Column width from longest suite name
col=10
for name in "${_suite_names[@]}"; do
  [ ${#name} -gt "$col" ] && col=${#name}
done

# ============================================================================
# ASCII box table
# ============================================================================

divider=$(printf '%0.s─' $(seq 1 $((col + 56))))

echo ""
echo "┌${divider}┐"
printf "│%*s│\n" $((col + 56)) ""
if [ "$_any_failure" -gt 0 ]; then
  label="SOME TESTS FAILED"
  pad_total=$((col + 56 - ${#label}))
  pad_left=$((pad_total / 2))
  pad_right=$((pad_total - pad_left))
  printf "│$(printf '%*s' "$pad_left" "")${RED}${BOLD}%s${NC}$(printf '%*s' "$pad_right" "")│\n" "$label"
else
  label="ALL ${_suite_count} SUITES PASSED (${_grand_total} tests)"
  pad_total=$((col + 56 - ${#label}))
  pad_left=$((pad_total / 2))
  pad_right=$((pad_total - pad_left))
  printf "│$(printf '%*s' "$pad_left" "")${GREEN}${BOLD}%s${NC}$(printf '%*s' "$pad_right" "")│\n" "$label"
fi
printf "│%*s│\n" $((col + 56)) ""
echo "├${divider}┤"

# Table header
printf "│ ${BOLD}%-${col}s │ %7s │ %7s │ %7s │ %-6s │ %-19s${NC} │\n" "Suite" "Passed" "Failed" "Total" "Result" "Ran At"
echo "├${divider}┤"

# Suite rows
for i in $(seq 0 $((_suite_count - 1))); do
  if [ "${_suite_failed[$i]}" -gt 0 ]; then
    status="${RED}FAIL${NC}  "
  else
    status="${GREEN}PASS${NC}  "
  fi
  printf "│ %-${col}s │ %7d │ %7d │ %7d │ %b│ %-19s │\n" \
    "${_suite_names[$i]}" "${_suite_passed[$i]}" "${_suite_failed[$i]}" "${_suite_totals[$i]}" "$status" "${_suite_times[$i]}"
done

if [ "$_suite_count" -eq 0 ]; then
  printf "│ ${DIM}%-$((col + 54))s${NC} │\n" "No test results found in $TEST_RESULTS_DIR/"
fi

# Totals row
echo "├${divider}┤"
if [ "$_any_failure" -gt 0 ]; then
  result_label="${RED}${BOLD}FAIL${NC}  "
else
  result_label="${GREEN}${BOLD}PASS${NC}  "
fi
printf "│ ${BOLD}%-${col}s${NC} │ ${BOLD}%7d${NC} │ ${BOLD}%7d${NC} │ ${BOLD}%7d${NC} │ %b│ %-19s │\n" \
  "TOTAL" "$_total_passed" "$_total_failed" "$_grand_total" "$result_label" ""
echo "└${divider}┘"
echo ""

# Log file listing
if ls "$TEST_LOGS_DIR"/*.txt >/dev/null 2>&1; then
  echo -e "${DIM}Log files:${NC}"
  for log in "$TEST_LOGS_DIR"/*.txt; do
    echo -e "  ${DIM}$log${NC}"
  done
  echo ""
fi

echo -e "${DIM}Result files: $TEST_RESULTS_DIR/*.json${NC}"
echo -e "${DIM}Markdown report: $REPORTS_DIR/summary.md${NC}"
echo ""

# TUI mode: sleep so the user can read the summary before process-compose exits
if [ "${TEST_TUI:-false}" = "true" ] || [ "${TEST_TUI:-0}" = "1" ]; then
  echo -e "${DIM}TUI mode: waiting 30s before exit (Ctrl+C to skip)...${NC}"
  sleep 30 || true
fi

# Exit with failure if any tests failed
if [ "$_any_failure" -gt 0 ]; then
  exit 1
fi
