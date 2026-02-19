#!/usr/bin/env bash
# Test Suite Summary Generator
# Aggregates results from reports/results/*.json written by test_summary()
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

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================================
# Collect results from JSON files
# ============================================================================

total_passed=0
total_failed=0
suite_count=0
any_failure=0

# Collect suite data into parallel arrays for reuse
suite_names=()
suite_passed=()
suite_failed=()
suite_totals=()

for result_file in $(ls "$TEST_RESULTS_DIR"/*.json 2>/dev/null | sort); do
  [ -f "$result_file" ] || continue
  name=$(jq -r '.suite // "unknown"' "$result_file" 2>/dev/null)
  p=$(jq -r '.passed // 0' "$result_file" 2>/dev/null)
  f=$(jq -r '.failed // 0' "$result_file" 2>/dev/null)
  t=$(jq -r '.total // 0' "$result_file" 2>/dev/null)

  suite_names+=("$name")
  suite_passed+=("$p")
  suite_failed+=("$f")
  suite_totals+=("$t")

  total_passed=$((total_passed + p))
  total_failed=$((total_failed + f))
  suite_count=$((suite_count + 1))
  if [ "$f" -gt 0 ]; then any_failure=1; fi
done

grand_total=$((total_passed + total_failed))

# Compute column width from longest suite name
col=10
for name in "${suite_names[@]}"; do
  [ ${#name} -gt "$col" ] && col=${#name}
done

# ============================================================================
# ASCII output
# ============================================================================

divider=$(printf '%0.s─' $(seq 1 $((col + 36))))

echo ""
echo "┌${divider}┐"
printf "│%*s│\n" $((col + 36)) ""
if [ "$any_failure" -gt 0 ]; then
  printf "│$(printf '%*s' $(( (col + 36 - 18) / 2 )) "")${RED}${BOLD}SOME TESTS FAILED${NC}$(printf '%*s' $(( (col + 36 - 18 + 1) / 2 )) "")│\n"
else
  label="ALL ${suite_count} SUITES PASSED (${grand_total} tests)"
  pad_total=$((col + 36 - ${#label}))
  pad_left=$((pad_total / 2))
  pad_right=$((pad_total - pad_left))
  printf "│$(printf '%*s' "$pad_left" "")${GREEN}${BOLD}%s${NC}$(printf '%*s' "$pad_right" "")│\n" "$label"
fi
printf "│%*s│\n" $((col + 36)) ""
echo "├${divider}┤"

# Table header
printf "│ ${BOLD}%-${col}s │ %7s │ %7s │ %7s │ %-6s${NC} │\n" "Suite" "Passed" "Failed" "Total" "Result"
echo "├${divider}┤"

# Suite rows
for i in $(seq 0 $((suite_count - 1))); do
  if [ "${suite_failed[$i]}" -gt 0 ]; then
    status="${RED}FAIL${NC}  "
  else
    status="${GREEN}PASS${NC}  "
  fi
  printf "│ %-${col}s │ %7d │ %7d │ %7d │ %b│\n" \
    "${suite_names[$i]}" "${suite_passed[$i]}" "${suite_failed[$i]}" "${suite_totals[$i]}" "$status"
done

if [ "$suite_count" -eq 0 ]; then
  printf "│ ${DIM}%-$((col + 34))s${NC} │\n" "No test results found in $TEST_RESULTS_DIR/"
fi

# Totals row
echo "├${divider}┤"
if [ "$any_failure" -gt 0 ]; then
  result_label="${RED}${BOLD}FAIL${NC}  "
else
  result_label="${GREEN}${BOLD}PASS${NC}  "
fi
printf "│ ${BOLD}%-${col}s${NC} │ ${BOLD}%7d${NC} │ ${BOLD}%7d${NC} │ ${BOLD}%7d${NC} │ %b│\n" \
  "TOTAL" "$total_passed" "$total_failed" "$grand_total" "$result_label"
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
echo ""

# ============================================================================
# Markdown report
# ============================================================================

summary_file="$REPORTS_DIR/summary.md"
mkdir -p "$REPORTS_DIR"

{
  echo "# Test Suite Summary"
  echo ""
  echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  if [ "$any_failure" -gt 0 ]; then
    echo "> **SOME TESTS FAILED**"
  else
    echo "> **ALL ${suite_count} SUITES PASSED** (${grand_total} tests)"
  fi
  echo ""

  # Markdown table
  echo "| Suite | Passed | Failed | Total | Result |"
  echo "|-------|-------:|-------:|------:|--------|"

  for i in $(seq 0 $((suite_count - 1))); do
    if [ "${suite_failed[$i]}" -gt 0 ]; then
      badge="FAIL"
    else
      badge="PASS"
    fi
    echo "| ${suite_names[$i]} | ${suite_passed[$i]} | ${suite_failed[$i]} | ${suite_totals[$i]} | ${badge} |"
  done

  echo "| **TOTAL** | **${total_passed}** | **${total_failed}** | **${grand_total}** | **$([ "$any_failure" -gt 0 ] && echo "FAIL" || echo "PASS")** |"
  echo ""

  # Log files section
  echo "## Log Files"
  echo ""
  if ls "$TEST_LOGS_DIR"/*.txt >/dev/null 2>&1; then
    for log in "$TEST_LOGS_DIR"/*.txt; do
      echo "- \`$log\`"
    done
  fi
  echo "- \`$TEST_RESULTS_DIR/*.json\`"
  echo ""
  echo "---"
  echo ""
  echo "_Run \`devbox run test:fast\` to regenerate this summary_"
} > "$summary_file"

echo "Summary written to: $summary_file"
echo ""

# TUI mode: sleep so the user can read the summary before process-compose exits
if [ "${TEST_TUI:-false}" = "true" ] || [ "${TEST_TUI:-0}" = "1" ]; then
  echo -e "${DIM}TUI mode: waiting 30s before exit (Ctrl+C to skip)...${NC}"
  sleep 30 || true
fi

# Exit with failure if any tests failed
if [ "$any_failure" -gt 0 ]; then
  exit 1
fi
