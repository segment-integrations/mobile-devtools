#!/usr/bin/env bash
# React Native Plugin - Doctor Library Extensions
# React Native specific helper functions for doctor checks

if ! (return 0 2>/dev/null); then
  echo "ERROR: doctor.sh must be sourced, not executed directly" >&2
  exit 1
fi

# Guard against multiple sourcing
if [ "${RN_DOCTOR_LIB_LOADED:-}" = "1" ]; then
  return 0
fi
RN_DOCTOR_LIB_LOADED=1

# ============================================================================
# React Native Specific Checks
# ============================================================================

rn_check_node_version() {
  local check_name="Node.js version"
  local min_version="${1:-18}"

  if command -v node >/dev/null 2>&1; then
    node_version=$(node --version 2>/dev/null | sed 's/v//')
    node_major=$(echo "$node_version" | cut -d. -f1)

    if [ "$node_major" -ge "$min_version" ]; then
      doctor_check_pass "$check_name (>= ${min_version}.x)"
      printf "  %s Node.js: v%s\n" "$(doctor_color_green "ℹ")" "$node_version"
    else
      doctor_check_warn "$check_name" "v${node_version} installed, but >= ${min_version}.x recommended"
    fi
  else
    doctor_check_error "$check_name" "Node.js not found in PATH"
  fi
}

rn_check_package_json() {
  local check_name="package.json"

  if [ -f "package.json" ]; then
    doctor_check_pass "$check_name exists"

    # Check for React Native dependency
    if command -v jq >/dev/null 2>&1; then
      rn_version=$(jq -r '.dependencies["react-native"] // .devDependencies["react-native"] // "not found"' package.json 2>/dev/null)
      if [ "$rn_version" != "not found" ]; then
        printf "  %s React Native: %s\n" "$(doctor_color_green "ℹ")" "$rn_version"
      else
        doctor_check_warn "React Native dependency" "react-native not found in package.json dependencies"
      fi
    fi
  else
    doctor_check_error "$check_name exists" "package.json not found in current directory"
  fi
}

rn_check_node_modules() {
  local check_name="node_modules installed"

  if [ -d "node_modules" ]; then
    doctor_check_pass "$check_name"

    # Check if react-native is installed
    if [ -d "node_modules/react-native" ]; then
      doctor_check_pass "react-native module installed"
    else
      doctor_check_warn "react-native module installed" "node_modules exists but react-native not found"
    fi
  else
    doctor_check_warn "$check_name" "Run: npm install or yarn install"
  fi
}

rn_check_metro_port() {
  local check_name="Metro port available"
  local port="${1:-8081}"

  if command -v lsof >/dev/null 2>&1; then
    if lsof -i:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
      doctor_check_warn "$check_name (${port})" "Port ${port} is in use (Metro may already be running)"
    else
      doctor_check_pass "$check_name (${port})"
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -an | grep -q ":${port}.*LISTEN"; then
      doctor_check_warn "$check_name (${port})" "Port ${port} is in use (Metro may already be running)"
    else
      doctor_check_pass "$check_name (${port})"
    fi
  else
    # Can't check - not a problem
    printf "  %s Metro port check: skipped (lsof/netstat not available)\n" "$(doctor_color_green "ℹ")"
  fi
}
