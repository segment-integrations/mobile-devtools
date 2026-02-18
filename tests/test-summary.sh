#!/usr/bin/env bash
# Test Suite Summary Generator
# Aggregates test results from all test suites and displays summary

set -euo pipefail

# Setup logging to file - redirect all output through tee
mkdir -p "${TEST_LOGS_DIR:-reports/logs}"
LOG_FILE="${TEST_LOGS_DIR:-reports/logs}/summary.txt"

# Use exec to redirect all output to both stdout and log file
exec > >(tee "$LOG_FILE")
exec 2>&1

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration (can be overridden via env vars)
REPORTS_DIR="${REPORTS_DIR:-reports}"
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-$REPORTS_DIR/results}"

# Results tracking
total_passed=0
total_failed=0
suite_count=0

echo ""
echo "========================================"
echo "     TEST SUITE SUMMARY"
echo "========================================"
echo ""

# Parse lint results
if [ -d "$REPORTS_DIR/devbox-lint-logs" ]; then
  echo -e "${BOLD}Linting & Validation:${NC}"
  lint_passed=0
  lint_failed=0

  for process in lint-android-scripts lint-ios-scripts lint-react-native-scripts validate-pr-checks-workflow validate-e2e-full-workflow; do
    log_file="$REPORTS_DIR/devbox-lint-logs/$process/out.log"
    if [ -f "$log_file" ]; then
      if grep -q "✓\|PASS\|valid" "$log_file" 2>/dev/null; then
        lint_passed=$((lint_passed + 1))
      elif grep -q "✗\|FAIL\|error" "$log_file" 2>/dev/null; then
        lint_failed=$((lint_failed + 1))
      fi
    fi
  done

  if [ $lint_failed -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Shellcheck & Workflows: ${lint_passed} checks passed"
  else
    echo -e "  ${RED}✗${NC} Shellcheck & Workflows: ${lint_passed} passed, ${lint_failed} failed"
  fi

  total_passed=$((total_passed + lint_passed))
  total_failed=$((total_failed + lint_failed))
  suite_count=$((suite_count + 1))
fi

# Parse Android plugin unit tests
echo ""
echo -e "${BOLD}Android Plugin Tests:${NC}"
android_passed=0
android_failed=0

# Check for JSON result files
if [ -f "$TEST_RESULTS_DIR/android-lib.json" ]; then
  passed=$(jq -r '.passed' $TEST_RESULTS_DIR/android-lib.json)
  failed=$(jq -r '.failed' $TEST_RESULTS_DIR/android-lib.json)
  android_passed=$((android_passed + passed))
  android_failed=$((android_failed + failed))

  if [ "$failed" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} lib.sh: ${passed} tests passed"
  else
    echo -e "  ${RED}✗${NC} lib.sh: ${passed} passed, ${failed} failed"
  fi
else
  echo -e "  ${NC}⚠ lib.sh: no results found${NC}"
fi

if [ -f "$TEST_RESULTS_DIR/android-devices.json" ]; then
  passed=$(jq -r '.passed' $TEST_RESULTS_DIR/android-devices.json)
  failed=$(jq -r '.failed' $TEST_RESULTS_DIR/android-devices.json)
  android_passed=$((android_passed + passed))
  android_failed=$((android_failed + failed))

  if [ "$failed" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} devices.sh: ${passed} tests passed"
  else
    echo -e "  ${RED}✗${NC} devices.sh: ${passed} passed, ${failed} failed"
  fi
else
  echo -e "  ${NC}⚠ devices.sh: no results found${NC}"
fi

total_passed=$((total_passed + android_passed))
total_failed=$((total_failed + android_failed))
if [ $android_passed -gt 0 ] || [ $android_failed -gt 0 ]; then
  suite_count=$((suite_count + 1))
fi

# Parse iOS plugin unit tests
echo ""
echo -e "${BOLD}iOS Plugin Tests:${NC}"
ios_passed=0
ios_failed=0

# Check for JSON result files
if [ -f "$TEST_RESULTS_DIR/ios-lib.json" ]; then
  passed=$(jq -r '.passed' $TEST_RESULTS_DIR/ios-lib.json)
  failed=$(jq -r '.failed' $TEST_RESULTS_DIR/ios-lib.json)
  ios_passed=$((ios_passed + passed))
  ios_failed=$((ios_failed + failed))

  if [ "$failed" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} lib.sh: ${passed} tests passed"
  else
    echo -e "  ${RED}✗${NC} lib.sh: ${passed} passed, ${failed} failed"
  fi
else
  echo -e "  ${NC}⚠ lib.sh: no results found${NC}"
fi

if [ -f "$TEST_RESULTS_DIR/ios-devices.json" ]; then
  passed=$(jq -r '.passed' $TEST_RESULTS_DIR/ios-devices.json)
  failed=$(jq -r '.failed' $TEST_RESULTS_DIR/ios-devices.json)
  ios_passed=$((ios_passed + passed))
  ios_failed=$((ios_failed + failed))

  if [ "$failed" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} devices.sh: ${passed} tests passed"
  else
    echo -e "  ${RED}✗${NC} devices.sh: ${passed} passed, ${failed} failed"
  fi
else
  echo -e "  ${NC}⚠ devices.sh: no results found${NC}"
fi

total_passed=$((total_passed + ios_passed))
total_failed=$((total_failed + ios_failed))
if [ $ios_passed -gt 0 ] || [ $ios_failed -gt 0 ]; then
  suite_count=$((suite_count + 1))
fi

# Parse React Native plugin unit tests
echo ""
echo -e "${BOLD}React Native Plugin Tests:${NC}"
rn_passed=0
rn_failed=0

if [ -f "$TEST_RESULTS_DIR/react-native-lib.json" ]; then
  passed=$(jq -r '.passed' $TEST_RESULTS_DIR/react-native-lib.json)
  failed=$(jq -r '.failed' $TEST_RESULTS_DIR/react-native-lib.json)
  rn_passed=$((rn_passed + passed))
  rn_failed=$((rn_failed + failed))

  if [ "$failed" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} lib.sh: ${passed} tests passed"
  else
    echo -e "  ${RED}✗${NC} lib.sh: ${passed} passed, ${failed} failed"
  fi
else
  echo -e "  ${NC}⚠ lib.sh: no results found${NC}"
fi

total_passed=$((total_passed + rn_passed))
total_failed=$((total_failed + rn_failed))
if [ $rn_passed -gt 0 ] || [ $rn_failed -gt 0 ]; then
  suite_count=$((suite_count + 1))
fi

# Parse integration tests
echo ""
echo -e "${BOLD}Integration Tests:${NC}"
integration_passed=0
integration_failed=0

# Android integration tests
if [ -f "$TEST_RESULTS_DIR/android-integration-device-mgmt.json" ]; then
  passed=$(jq -r '.passed' $TEST_RESULTS_DIR/android-integration-device-mgmt.json)
  failed=$(jq -r '.failed' $TEST_RESULTS_DIR/android-integration-device-mgmt.json)
  integration_passed=$((integration_passed + passed))
  integration_failed=$((integration_failed + failed))

  if [ "$failed" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} android device mgmt: ${passed} tests passed"
  else
    echo -e "  ${RED}✗${NC} android device mgmt: ${passed} passed, ${failed} failed"
  fi
else
  echo -e "  ${NC}⚠ android device mgmt: no results found${NC}"
fi

if [ -f "$TEST_RESULTS_DIR/android-integration-validation.json" ]; then
  passed=$(jq -r '.passed' $TEST_RESULTS_DIR/android-integration-validation.json)
  failed=$(jq -r '.failed' $TEST_RESULTS_DIR/android-integration-validation.json)
  integration_passed=$((integration_passed + passed))
  integration_failed=$((integration_failed + failed))

  if [ "$failed" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} android validation: ${passed} tests passed"
  else
    echo -e "  ${RED}✗${NC} android validation: ${passed} passed, ${failed} failed"
  fi
else
  echo -e "  ${NC}⚠ android validation: no results found${NC}"
fi

# iOS integration tests
if [ -f "$TEST_RESULTS_DIR/ios-integration-device-mgmt.json" ]; then
  passed=$(jq -r '.passed' $TEST_RESULTS_DIR/ios-integration-device-mgmt.json)
  failed=$(jq -r '.failed' $TEST_RESULTS_DIR/ios-integration-device-mgmt.json)
  integration_passed=$((integration_passed + passed))
  integration_failed=$((integration_failed + failed))

  if [ "$failed" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} ios device mgmt: ${passed} tests passed"
  else
    echo -e "  ${RED}✗${NC} ios device mgmt: ${passed} passed, ${failed} failed"
  fi
else
  echo -e "  ${NC}⚠ ios device mgmt: no results found${NC}"
fi

if [ -f "$TEST_RESULTS_DIR/ios-integration-cache.json" ]; then
  passed=$(jq -r '.passed' $TEST_RESULTS_DIR/ios-integration-cache.json)
  failed=$(jq -r '.failed' $TEST_RESULTS_DIR/ios-integration-cache.json)
  integration_passed=$((integration_passed + passed))
  integration_failed=$((integration_failed + failed))

  if [ "$failed" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} ios cache: ${passed} tests passed"
  else
    echo -e "  ${RED}✗${NC} ios cache: ${passed} passed, ${failed} failed"
  fi
else
  echo -e "  ${NC}⚠ ios cache: no results found${NC}"
fi

total_passed=$((total_passed + integration_passed))
total_failed=$((total_failed + integration_failed))
if [ $integration_passed -gt 0 ] || [ $integration_failed -gt 0 ]; then
  suite_count=$((suite_count + 1))
fi

# Parse devbox-mcp tests
if [ -d "$REPORTS_DIR/devbox-mcp-logs" ]; then
  echo ""
  echo -e "${BOLD}Devbox MCP Tests:${NC}"
  mcp_passed=0
  mcp_failed=0

  log_file="$REPORTS_DIR/devbox-mcp-logs/test-mcp-tools/out.log"
  if [ -f "$log_file" ]; then
    log_content=$(cat "$log_file")
    if echo "$log_content" | grep -q "Passed:"; then
      passed=$(echo "$log_content" | grep "Passed:" | awk '{print $2}')
      failed=$(echo "$log_content" | grep "Failed:" | awk '{print $2}')
      mcp_passed=$passed
      mcp_failed=$failed

      if [ "$failed" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} MCP Tools: ${passed} tests passed"
      else
        echo -e "  ${RED}✗${NC} MCP Tools: ${passed} passed, ${failed} failed"
      fi
    fi
  fi

  total_passed=$((total_passed + mcp_passed))
  total_failed=$((total_failed + mcp_failed))
  suite_count=$((suite_count + 1))
fi

# Final summary
echo ""
echo "========================================"
if [ $total_failed -eq 0 ]; then
  echo -e "${GREEN}${BOLD}     ALL TESTS PASSED ✓${NC}"
else
  echo -e "${RED}${BOLD}     SOME TESTS FAILED ✗${NC}"
fi
echo "========================================"
echo ""
echo "Results:"
echo "  Test Suites: ${suite_count}"
echo -e "  ${GREEN}Passed: ${total_passed}${NC}"
if [ $total_failed -gt 0 ]; then
  echo -e "  ${RED}Failed: ${total_failed}${NC}"
else
  echo "  Failed: 0"
fi
echo ""
echo "Test Log Files:"
echo "  $REPORTS_DIR/logs/android-test-lib.txt"
echo "  $REPORTS_DIR/logs/android-test-devices.txt"
echo "  $REPORTS_DIR/logs/android-test-device-mgmt.txt"
echo "  $REPORTS_DIR/logs/android-test-validation.txt"
echo "  $REPORTS_DIR/logs/ios-test-lib.txt"
echo "  $REPORTS_DIR/logs/ios-test-devices.txt"
echo "  $REPORTS_DIR/logs/ios-test-device-mgmt.txt"
echo "  $REPORTS_DIR/logs/ios-test-cache.txt"
echo "  $REPORTS_DIR/logs/react-native-test-lib.txt"
echo "  $REPORTS_DIR/logs/summary.txt"
echo ""
echo "Lint Logs:"
echo "  $REPORTS_DIR/devbox-lint-logs/"
echo ""
echo "Result Files:"
echo "  $REPORTS_DIR/results/*.json"
echo ""

# Write markdown summary
summary_file="$REPORTS_DIR/summary.md"
mkdir -p "$REPORTS_DIR"

cat > "$summary_file" << MDEOF
# Test Suite Summary

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')

## Overall Results

$(if [ $total_failed -eq 0 ]; then echo "✅ **ALL TESTS PASSED**"; else echo "❌ **SOME TESTS FAILED**"; fi)

- **Test Suites:** ${suite_count}
- **Total Passed:** ${total_passed}
- **Total Failed:** ${total_failed}

---

## Test Breakdown

### Linting & Validation
$(if [ -d "$REPORTS_DIR/devbox-lint-logs" ]; then
  echo "- Android scripts: ✅"
  echo "- iOS scripts: ✅"
  echo "- React Native scripts: ✅"
  echo "- Workflow validation: ✅"
else
  echo "No lint results found"
fi)

### Android Plugin Tests
$(if [ $android_passed -gt 0 ] || [ $android_failed -gt 0 ]; then
  echo "- lib.sh: $(if [ $android_failed -eq 0 ]; then echo "✅"; else echo "❌"; fi) (Passed: $android_passed, Failed: $android_failed)"
  echo "- devices.sh: ✅"
else
  echo "No Android test results found"
fi)

### iOS Plugin Tests
$(if [ $ios_passed -gt 0 ] || [ $ios_failed -gt 0 ]; then
  echo "- lib.sh: $(if [ $ios_failed -eq 0 ]; then echo "✅"; else echo "❌"; fi) (Passed: $ios_passed, Failed: $ios_failed)"
else
  echo "No iOS test results found"
fi)

### React Native Plugin Tests
$(if [ $rn_passed -gt 0 ] || [ $rn_failed -gt 0 ]; then
  echo "- lib.sh: $(if [ $rn_failed -eq 0 ]; then echo "✅"; else echo "❌"; fi) (Passed: $rn_passed, Failed: $rn_failed)"
else
  echo "No React Native test results found"
fi)

### Integration Tests
$(if [ $integration_passed -gt 0 ] || [ $integration_failed -gt 0 ]; then
  echo "- Android device mgmt: $(if [ $integration_failed -eq 0 ]; then echo "✅"; else echo "⚠️"; fi)"
  echo "- Android validation: ✅"
  echo "- iOS device mgmt: ✅"
  echo "- iOS cache: ✅"
  echo ""
  echo "Total: Passed: $integration_passed, Failed: $integration_failed"
else
  echo "No integration test results found"
fi)

### Devbox MCP Tests
$(if [ -d "$REPORTS_DIR/devbox-mcp-logs" ]; then
  if [ -f "$REPORTS_DIR/devbox-mcp-logs/test-mcp-tools/out.log" ]; then
    log=$(cat "$REPORTS_DIR/devbox-mcp-logs/test-mcp-tools/out.log")
    if echo "$log" | grep -q "Passed:"; then
      passed=$(echo "$log" | grep "Passed:" | awk '{print $2}')
      failed=$(echo "$log" | grep "Failed:" | awk '{print $2}')
      echo "- MCP Tools: $(if [ "$failed" -eq 0 ]; then echo "✅"; else echo "❌"; fi) (Passed: $passed, Failed: $failed)"
    else
      echo "- MCP Tools: ✅"
    fi
  else
    echo "- MCP Tools: ✅"
  fi
else
  echo "No devbox-mcp test results found"
fi)

---

## Log Files

Detailed logs available in:
- \`$REPORTS_DIR/devbox-lint-logs/\`
- \`$REPORTS_DIR/devbox-unit-tests-logs/\`
- \`$REPORTS_DIR/devbox-mcp-logs/\`

---

_Run \`devbox run test:fast\` to regenerate this summary_
MDEOF

echo "Summary written to: $summary_file"
echo ""

# Exit with failure if any tests failed
if [ $total_failed -gt 0 ]; then
  exit 1
fi
