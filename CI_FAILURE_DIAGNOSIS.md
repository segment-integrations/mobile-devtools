# CI Failure Diagnosis Report

**Job:** Android E2E - max  
**Run:** https://github.com/segment-integrations/mobile-devtools/actions/runs/24703354216/job/72251545373  
**Status:** Cancelled after 30 minutes  
**Date:** 2026-04-21

## Executive Summary

The CI job failed because the device filtering logic has a **filename vs. name field mismatch**. When `ANDROID_DEVICES=max` is set, the system filters by the `.name` field inside JSON files (`medium_phone_api36`), but CI expects it to filter by filename (`max.json`). This causes ALL devices to be filtered out, emulator never starts, and the job times out.

---

## Root Cause Analysis

### The Bug

**Inconsistency between device selection semantics:**

1. **Device files** are named with **semantic identifiers**: `min.json`, `max.json`
2. **JSON `.name` field** contains **descriptive identifiers**: `pixel_api24`, `medium_phone_api36`
3. **Filtering logic** (in both `devices.sh:342` and `avd.sh:358`) compares against the **`.name` field**, not the filename
4. **CI configuration** sets `ANDROID_DEVICES=max` expecting **filename-based filtering**

### Evidence from Logs

```bash
# Line 209-214: Lock file successfully generated with 2 devices
[sync-avds] Lock file generated: 2 devices with APIs 36,21

# Line 215-220: Both devices filtered out (NOT what we want!)
[sync-avds]   ⊗ Filtered:  2 (ANDROID_DEVICES=max)

# Line 224: Fatal error - no devices match filter
[android-emulator] ERROR: No devices match ANDROID_DEVICES filter: max

# Lines 239-436: Test waits endlessly for emulator that never started
[verify-emulator-ready]   Waiting for emulator... s/s
```

### Evidence from Code

**Device file structure:**
```bash
$ cat examples/android/devbox.d/android/devices/max.json
{
  "name": "medium_phone_api36",  # ← Filter checks this
  "api": 36,
  "device": "medium_phone",
  "tag": "google_apis"
}
```

**Filtering logic (avd.sh:358):**
```bash
for device_json in $devices_json; do
  device_name="$(echo "$device_json" | jq -r '.name // empty')"
  
  # Check if device is in selected list
  should_include=false
  for selected in "${selected_devices[@]}"; do
    if [ "$device_name" = "$selected" ]; then  # ← Checks .name field
      should_include=true
      break
    fi
  done
```

**What happens:**
- `ANDROID_DEVICES=max` → looking for device where `.name == "max"`
- Actual device names: `pixel_api24`, `medium_phone_api36`
- No match → filters out ALL devices → emulator never starts → timeout

### Sequence of Events

1. **04:07:16** - Job starts
2. **04:10:14** - Nix flake evaluation completes (~3 minutes)
3. **04:12:54** - AVD sync begins
4. **04:12:54** - Lock file generated: 2 devices (APIs 36, 21)
5. **04:12:54** - **BUG:** Both devices filtered out (ANDROID_DEVICES=max)
6. **04:12:54** - Emulator start attempted with device "max"
7. **04:12:54** - **ERROR:** No devices match ANDROID_DEVICES filter: max
8. **04:12:59** - Test begins waiting for emulator
9. **04:13:08** - App builds successfully (13 seconds)
10. **04:13:08 - 04:37:28** - Test waits endlessly (25 minutes)
11. **04:37:28** - Job cancelled by timeout

---

## Impact Assessment

### What Failed
- ✅ Nix setup (successful)
- ✅ SDK installation (successful)
- ✅ Lock file generation (successful)
- ❌ **Device filtering (BROKEN)**
- ❌ **Emulator startup (never happened)**
- ❌ **E2E test execution (never ran)**

### Why This Wasn't Caught Earlier

1. **Recent change introduced bug** (commit `133bdc6` on 2026-04-20)
2. **Filtering logic added** to fix a different issue (strict mode failures)
3. **Assumed `.name` field = filename** (incorrect assumption)
4. **No validation** that filtered device list is non-empty before emulator start

---

## Blind Spots in Logging & Error Handling

### Critical Missing Information

#### 1. **No logging of available device names during filtering**

**Current behavior:**
```bash
[sync-avds]   ⊗ Filtered:  2 (ANDROID_DEVICES=max)
```

**What we need:**
```bash
[sync-avds] Available devices: pixel_api24, medium_phone_api36
[sync-avds] Filter: ANDROID_DEVICES=max
[sync-avds] ⊗ No devices match filter
[sync-avds] ERROR: ANDROID_DEVICES expects filename (min/max) but filter checks .name field
```

#### 2. **No early validation of ANDROID_DEVICES filter**

**Current:** Filter happens in two places (devices.sh sync, avd.sh setup), error only at emulator start  
**Should:** Validate filter immediately when devices.lock is read, fail fast with clear message

**Suggested validation:**
```bash
android_validate_device_filter() {
  local filter="$1"
  local devices_json="$2"
  
  # Extract all device names from lock file
  local available_names="$(echo "$devices_json" | jq -r '.name' | tr '\n' ', ')"
  
  # Check if any devices match
  local matched=0
  for device_json in $devices_json; do
    device_name="$(echo "$device_json" | jq -r '.name // empty')"
    if [ "$device_name" = "$filter" ]; then
      matched=$((matched + 1))
    fi
  done
  
  if [ "$matched" -eq 0 ]; then
    echo "ERROR: ANDROID_DEVICES filter '$filter' matches no devices" >&2
    echo "       Available device names: $available_names" >&2
    echo "       Available filenames: min, max" >&2
    echo "       HINT: Filter checks .name field, not filename" >&2
    exit 1
  fi
}
```

#### 3. **No distinction between "filter error" vs "system image missing"**

Both produce similar "skipped devices" output, but root causes are different:
- **Filter error**: Configuration bug (wrong filter value)
- **System image missing**: Environment issue (need to re-enter devbox shell)

**Should log differently:**
```bash
# Filter error (configuration bug)
ERROR: Device filter mismatch
  Filter: max
  Available: pixel_api24, medium_phone_api36
  Fix: Update ANDROID_DEVICES or rename device .name field

# System image missing (environment issue)
WARNING: System image not available for pixel_api24 (API 24)
  Fix: Exit and re-enter devbox shell to download system images
```

#### 4. **No logging of what emulator.sh received**

**Current:** `emulator.sh` called with device "max", immediately fails  
**Should:** Log what was requested vs. what's available

```bash
[emulator.sh] Requested device: max
[emulator.sh] Checking devices.lock...
[emulator.sh] Available devices: pixel_api24, medium_phone_api36
[emulator.sh] ERROR: Device 'max' not found
[emulator.sh] HINT: Use device name from .name field, not filename
```

#### 5. **verify-emulator-ready has no timeout/failure detection**

**Current:** Waits indefinitely polling for emulator  
**Should:** Detect that emulator process never started

```bash
# Check if emulator process exists
if ! pgrep -f "emulator.*-avd" >/dev/null; then
  echo "ERROR: Emulator process not found after 60 seconds"
  echo "       Check emulator startup logs above"
  exit 1
fi
```

#### 6. **No structured logging for process-compose failures**

**Current:** Each process logs independently, hard to correlate failures  
**Should:** Summary process should detect and report cascading failures

```bash
[summary] Process check:
[summary]   ✓ setup-sdk: completed successfully
[summary]   ✓ sync-avds: completed successfully  
[summary]   ✗ android-emulator: failed with exit code 1
[summary]   ⏳ verify-emulator-ready: still waiting (TIMEOUT likely)
[summary]   ✓ build-app: completed successfully
[summary]
[summary] ERROR: android-emulator failed, verify-emulator-ready cannot succeed
[summary] Root cause: No devices match ANDROID_DEVICES filter
```

---

## Recommended Fixes

### Fix 1: Align filtering to use filename (RECOMMENDED)

**Rationale:** Filenames (`min.json`, `max.json`) are semantic and match CI usage

**Implementation:**

```bash
# In devices.sh (line 309-353) and avd.sh (line 347-375)
# Change from:
device_name="$(jq -r '.name // empty' "$device_json")"

# To:
# Extract filename without path and .json extension
device_file="$(echo "$device_json" | jq -r '.file // empty')"
device_basename="$(basename "$device_file" .json)"
```

**Benefits:**
- Matches intuitive usage: `ANDROID_DEVICES=min,max`
- No need to know internal `.name` field values
- CI works without changes

### Fix 2: Support both filename and .name field matching

**Rationale:** Provides flexibility for both semantic (min/max) and descriptive (pixel_api24) filtering

**Implementation:**

```bash
android_device_matches_filter() {
  local device_json="$1"
  local filter="$2"
  
  # Extract both filename and .name field
  device_file="$(echo "$device_json" | jq -r '.file // empty')"
  device_basename="$(basename "$device_file" .json)"
  device_name="$(echo "$device_json" | jq -r '.name // empty')"
  
  # Match either filename OR .name field
  if [ "$device_basename" = "$filter" ] || [ "$device_name" = "$filter" ]; then
    return 0
  fi
  return 1
}
```

**Benefits:**
- Backwards compatible with both approaches
- Supports semantic (min/max) and descriptive filtering
- Flexible for different use cases

### Fix 3: Improve error messages and validation

**Add to both filtering locations:**

```bash
if [ "${#selected_devices[@]}" -gt 0 ]; then
  # Log what we're filtering
  echo "Filtering devices: ${ANDROID_DEVICES}"
  echo "Available devices:"
  for device_json in $devices_json; do
    device_name="$(echo "$device_json" | jq -r '.name // empty')"
    device_file="$(echo "$device_json" | jq -r '.file // empty')"
    device_basename="$(basename "$device_file" .json)"
    echo "  - $device_basename (name: $device_name)"
  done
  
  # ... perform filtering ...
  
  # Validate result BEFORE continuing
  if [ -z "$devices_json" ]; then
    echo "ERROR: No devices match ANDROID_DEVICES filter: ${ANDROID_DEVICES}" >&2
    echo "       Check available device names above" >&2
    exit 1
  fi
fi
```

---

## Testing Plan

### Test Case 1: Filter by filename (min/max)
```bash
ANDROID_DEVICES=max devbox run android.sh devices sync
# Expected: Processes only max.json device
```

### Test Case 2: Filter by .name field
```bash
ANDROID_DEVICES=pixel_api24 devbox run android.sh devices sync
# Expected: Processes only device with name=pixel_api24
```

### Test Case 3: Invalid filter
```bash
ANDROID_DEVICES=nonexistent devbox run android.sh devices sync
# Expected: Clear error message listing available options
```

### Test Case 4: CI simulation
```bash
cd examples/android
ANDROID_DEVICES=max devbox run --pure test:e2e
# Expected: Runs e2e test with max device only
```

---

## Priority & Timeline

**Severity:** P0 - Blocking CI  
**Impact:** All Android E2E tests failing  
**Estimated Fix Time:** 1-2 hours  
**Testing Time:** 30 minutes  

---

## Related Issues

- Commit `133bdc6`: Introduced device filtering to fix strict mode failures
- Commit `3c88b92`: Added device filtering to sync command
- Original issue: CI flakiness with missing system images

The filtering logic was correct in intent but had a semantic mismatch between filename-based and name-based filtering.
