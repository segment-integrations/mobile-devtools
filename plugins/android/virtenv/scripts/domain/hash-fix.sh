#!/usr/bin/env bash
# Android SDK Hash Mismatch Auto-Fix
# Detects and fixes hash mismatches caused by Google updating files on their servers

set -e

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../lib/lib.sh" ]; then
  . "${SCRIPT_DIR}/../lib/lib.sh"
fi

android_hash_fix_detect_mismatch() {
  local nix_stderr="$1"

  # Extract hash mismatch info from nix error
  # Example: "specified: sha1-/4+s3hN+V5lBEmcqDQ9BGjynsgE="
  #          "got:      sha1-jEySbQyhkjdrKgSwMYSEckMZ5nw="

  if ! echo "$nix_stderr" | grep -q "hash mismatch in fixed-output derivation"; then
    return 1
  fi

  # Extract URL from error (look for https://dl.google.com/android/repository/...)
  local url
  url=$(echo "$nix_stderr" | grep -oE "https://dl\.google\.com/android/repository/[^'\"[:space:]]+")

  if [ -z "$url" ]; then
    echo "Could not extract URL from hash mismatch error" >&2
    return 1
  fi

  # Extract expected and actual hashes
  local expected_hash actual_hash
  expected_hash=$(echo "$nix_stderr" | grep "specified:" | grep -oE "sha1-[A-Za-z0-9+/=]+")
  actual_hash=$(echo "$nix_stderr" | grep "got:" | grep -oE "sha1-[A-Za-z0-9+/=]+")

  echo "HASH_MISMATCH_URL=$url"
  echo "HASH_MISMATCH_EXPECTED=$expected_hash"
  echo "HASH_MISMATCH_ACTUAL=$actual_hash"

  return 0
}

android_hash_fix_download_and_compute() {
  local url="$1"
  local temp_file

  temp_file=$(mktemp "${TMPDIR:-/tmp}/android-hash-fix-XXXXXX")

  echo "Downloading $url to verify hash..." >&2
  if ! curl -fsSL "$url" -o "$temp_file"; then
    echo "Failed to download $url" >&2
    rm -f "$temp_file"
    return 1
  fi

  # Compute SHA1
  local computed_hash
  if command -v sha1sum >/dev/null 2>&1; then
    computed_hash=$(sha1sum "$temp_file" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    computed_hash=$(shasum "$temp_file" | awk '{print $1}')
  else
    echo "No sha1sum or shasum command available" >&2
    rm -f "$temp_file"
    return 1
  fi

  rm -f "$temp_file"

  echo "$computed_hash"
  return 0
}

android_hash_fix_update_android_json() {
  local url="$1"
  local new_hash="$2"
  local android_json="${ANDROID_CONFIG_DIR}/android.json"

  if [ ! -f "$android_json" ]; then
    echo "android.json not found at $android_json" >&2
    return 1
  fi

  # Create override key from URL (replace / with -)
  local override_key
  override_key=$(echo "$url" | sed 's|https://||; s|/|-|g')

  # Update android.json with hash override
  local temp_json
  temp_json=$(mktemp)

  if ! jq --arg key "$override_key" --arg hash "$new_hash" \
    '.hash_overrides = (.hash_overrides // {}) | .hash_overrides[$key] = $hash' \
    "$android_json" > "$temp_json"; then
    echo "Failed to update android.json" >&2
    rm -f "$temp_json"
    return 1
  fi

  mv "$temp_json" "$android_json"
  echo "Updated $android_json with hash override for $url" >&2
  echo "  Override key: $override_key" >&2
  echo "  New hash: $new_hash" >&2

  return 0
}

android_hash_fix_auto() {
  local nix_error_log="${1:-}"
  local verbose="${ANDROID_HASH_FIX_VERBOSE:-0}"

  # If no log file specified, find the latest android-nix-build error log
  if [ -z "$nix_error_log" ] || [ ! -f "$nix_error_log" ]; then
    nix_error_log=$(find "${TMPDIR:-/tmp}" -name "android-nix-build-*.stderr" -type f 2>/dev/null | sort -r | head -n 1)
    if [ -z "$nix_error_log" ] || [ ! -f "$nix_error_log" ]; then
      echo "Error: No android-nix-build error log found" >&2
      echo "  Looked in: ${TMPDIR:-/tmp}/android-nix-build-*.stderr" >&2
      echo "" >&2
      echo "The error log is created when 'devbox shell' fails to build the Android SDK." >&2
      echo "Please try running 'devbox shell' first to trigger the hash mismatch error." >&2
      return 1
    fi
    if [ "$verbose" = "1" ]; then
      echo "Found error log: $nix_error_log" >&2
      echo "" >&2
    fi
  fi

  local nix_stderr
  nix_stderr=$(cat "$nix_error_log")

  if [ "$verbose" = "1" ]; then
    echo "🔍 Analyzing hash mismatch..." >&2
    echo "" >&2
  fi

  # Detect mismatch
  local mismatch_info
  if ! mismatch_info=$(android_hash_fix_detect_mismatch "$nix_stderr"); then
    echo "No hash mismatch detected in error log" >&2
    return 1
  fi

  eval "$mismatch_info"

  if [ -z "$HASH_MISMATCH_URL" ]; then
    echo "Could not extract mismatch info" >&2
    return 1
  fi

  # Extract filename from URL for display
  local filename
  filename=$(basename "$HASH_MISMATCH_URL")

  if [ "$verbose" = "1" ]; then
    echo "📦 File with mismatch: $HASH_MISMATCH_URL" >&2
    echo "   Expected: $HASH_MISMATCH_EXPECTED" >&2
    echo "   Got:      $HASH_MISMATCH_ACTUAL" >&2
    echo "" >&2
    echo "⬇️  Downloading file to verify hash..." >&2
  else
    echo "🔍 Detected mismatch in: $filename" >&2
    echo "⬇️  Downloading and verifying..." >&2
  fi

  # Download and compute actual hash
  local computed_hash
  if ! computed_hash=$(android_hash_fix_download_and_compute "$HASH_MISMATCH_URL" 2>/dev/null); then
    echo "Failed to download and compute hash" >&2
    return 1
  fi

  if [ "$verbose" = "1" ]; then
    echo "✓ Computed hash: $computed_hash" >&2
    echo "" >&2
    echo "📝 Updating android.json with hash override..." >&2
  fi

  # Update android.json
  if ! android_hash_fix_update_android_json "$HASH_MISMATCH_URL" "$computed_hash" 2>/dev/null; then
    if [ "$verbose" = "1" ]; then
      echo "Failed to update android.json" >&2
    fi
    return 1
  fi

  if [ "$verbose" = "1" ]; then
    echo "" >&2
    echo "✅ Hash override added to android.json" >&2
    echo "" >&2
    echo "Next steps:" >&2
    echo "  1. Run 'devbox shell' again to rebuild with corrected hash" >&2
    echo "  2. The fix is local and will work until nixpkgs is updated upstream" >&2
    echo "" >&2
  else
    echo "✓ Hash updated in android.json" >&2
  fi

  return 0
}

# If called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    detect)
      shift
      android_hash_fix_detect_mismatch "$@"
      ;;
    compute)
      shift
      android_hash_fix_download_and_compute "$@"
      ;;
    update)
      shift
      android_hash_fix_update_android_json "$@"
      ;;
    auto)
      shift
      android_hash_fix_auto "$@"
      ;;
    *)
      echo "Usage: $0 {detect|compute|update|auto} [args...]" >&2
      exit 1
      ;;
  esac
fi
