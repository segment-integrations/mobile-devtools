# Environment Variable Setup Strategy

This document defines the standardized approach for environment variable setup across all plugins (Android, iOS, React Native).

## Hierarchy and Responsibility

### 1. Static Environment Variables → `plugin.json`
**Purpose:** Project-scoped configuration that doesn't require computation

**What belongs here:**
- Path templates using devbox variables (`{{ .Virtenv }}`, `{{ .DevboxDir }}`)
- Default configuration values that users commonly override
- Feature flags and boolean settings
- Version specifications

**Android plugin.json examples:**
```json
{
  "ANDROID_USER_HOME": "{{ .Virtenv }}/android",
    // → Justification: Project-local storage path, templated
  "ANDROID_DEFAULT_DEVICE": "max",
    // → Justification: User frequently overrides per project
  "ANDROID_BUILD_CONFIG": "Debug",
    // → Justification: Common override for Release builds
  "ANDROID_COMPILE_SDK": "36",
    // → Justification: Version number, no computation needed
  "ANDROID_LOCAL_SDK": "0",
    // → Justification: Boolean flag, user decides Nix vs local
  "ANDROID_SKIP_SETUP": "0"
    // → Justification: Feature flag for React Native iOS-only mode
}
```

**React Native plugin.json overrides:**
```json
{
  "ANDROID_BUILD_CONFIG": "Release",
    // → Justification: React Native defaults to Release for better perf
  "IOS_BUILD_CONFIG": "Release"
    // → Justification: Same reasoning as Android
}
```

**iOS plugin.json examples:**
```json
{
  "IOS_RUNTIME_DIR": "{{ .Virtenv }}/ios/runtime",
    // → Justification: Project-local storage path, templated
  "IOS_DEFAULT_DEVICE": "max",
    // → Justification: User frequently overrides per project
  "IOS_DOWNLOAD_RUNTIME": "1",
    // → Justification: Boolean flag, user decides auto-download behavior
  "IOS_SKIP_SETUP": "0"
    // → Justification: Feature flag for React Native Android-only mode
}
```

**Rules:**
- Use devbox template syntax for paths
- No logic or conditionals - if it needs computation, it goes in core.sh
- Can be overridden in project's devbox.json (inheritance pattern)
- Plugins can override values from included plugins (React Native overrides Android/iOS)

---

### 2. Computed Environment Setup → `platform/core.sh`
**Purpose:** SDK/toolchain resolution that requires logic

**What belongs here:**
- SDK paths that require detection or building from Nix
- Toolchain paths that require searching the system
- PATH modifications that depend on resolved SDKs
- Environment variables that need conditional logic

**Android core.sh examples:**
```bash
android_setup_sdk_environment() {
  # ANDROID_SDK_ROOT
  # → Justification: Requires Nix flake evaluation OR multi-strategy local detection
  #   Strategy: 1. Nix flake, 2. sdkmanager detection, 3. tool detection
  ANDROID_SDK_ROOT="$(resolve_flake_sdk_root "$ANDROID_SDK_FLAKE_OUTPUT" || ...)"

  # ANDROID_HOME
  # → Justification: Compatibility alias, derived from ANDROID_SDK_ROOT
  ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"

  # ANDROID_JAVA_HOME
  # → Justification: Java path resolution with fallback chain
  #   Strategy: 1. Existing ANDROID_JAVA_HOME, 2. JAVA_HOME, 3. java in PATH
  java_home="$(android_resolve_java_home 2>/dev/null || true)"
  ANDROID_JAVA_HOME="$java_home"

  export ANDROID_SDK_ROOT ANDROID_HOME ANDROID_JAVA_HOME
}

android_setup_path() {
  # PATH
  # → Justification: Depends on resolved ANDROID_SDK_ROOT, adds multiple tool dirs
  PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/tools/bin:$PATH"
  export PATH
}
```

**iOS core.sh examples:**
```bash
ios_setup_environment() {
  # DEVELOPER_DIR
  # → Justification: Xcode path resolution with multiple strategies
  #   Strategy: 1. IOS_DEVELOPER_DIR env, 2. Latest Xcode.app, 3. xcode-select, 4. fallback
  dev_dir="$(ios_resolve_developer_dir || true)"
  DEVELOPER_DIR="$dev_dir"

  # PATH
  # → Justification: Adds Xcode tools, depends on resolved DEVELOPER_DIR
  PATH="$DEVELOPER_DIR/usr/bin:$PATH"

  # CC, CXX
  # → Justification: Override Nix compiler to use system clang for iOS builds
  CC=/usr/bin/clang
  CXX=/usr/bin/clang++

  export DEVELOPER_DIR PATH CC CXX
}
```

**Rules:**
- ALL functions that export environment variables go here
- Named: `{platform}_setup_*` (e.g., `android_setup_sdk_environment`)
- Called during init by setup.sh, never called from domain scripts
- Use utility functions from lib.sh for resolution logic (keep core.sh focused on setup)

---

### 3. Initialization Orchestration → `init/setup.sh`
**Purpose:** Entry point that sources core.sh and calls setup functions

**Responsibilities:**
1. Double-load prevention
2. Platform/skip checks
3. Source core.sh
4. Call setup functions
5. Run validation (non-blocking)
6. Display summary (optional)

**Does NOT:**
- Define setup functions (those go in core.sh)
- Export variables directly (delegates to core.sh functions)

---

### 4. Runtime State → `domain/*.sh`
**Purpose:** Process-specific runtime state (persisted to suite-namespaced files)

**What belongs here:**
- **State files** (primary): Suite-namespaced state persisted to disk
  - `$ANDROID_RUNTIME_DIR/$SUITE_NAME/emulator-serial.txt`
  - `$IOS_RUNTIME_DIR/$SUITE_NAME/simulator-udid.txt`
  - `$ANDROID_RUNTIME_DIR/$SUITE_NAME/app-id.txt`

- **Environment variables** (internal): Process-scoped, not suite-safe
  - `ANDROID_EMULATOR_SERIAL` - Used within emulator start process
  - `ANDROID_DEVICE_NAME` - Used within device operations
  - `IOS_SIM_UDID` - Used within simulator start process
  - These are **implementation details**, not user-facing

**How concurrent test suites work:**
```bash
# Test suite A (SUITE_NAME=android-e2e)
android.sh emulator start
  → Writes to: .devbox/virtenv/android-e2e/emulator-serial.txt
  → Exports: ANDROID_EMULATOR_SERIAL=emulator-5556 (process-scoped)

# Test suite B (SUITE_NAME=rn-android-e2e)
android.sh emulator start
  → Writes to: .devbox/virtenv/rn-android-e2e/emulator-serial.txt
  → Exports: ANDROID_EMULATOR_SERIAL=emulator-5558 (different process)

# No conflict! Each suite reads its own state file.
```

**Rules:**
- State MUST be persisted to suite-namespaced files for concurrent execution
- Environment variables are okay for internal use within a process
- Do NOT rely on env vars across processes - use state files
- Assume core environment is already set up by init/setup.sh

---

### 5. Utility Functions → `lib/lib.sh`
**Purpose:** Pure functions that don't modify environment

**Examples:**
- `android_resolve_java_home()` - Returns path without exporting
- `android_require_tool()` - Validates tool availability
- `android_log_*()` - Logging functions

**Rules:**
- Return values via stdout
- Do NOT export environment variables
- Can be used by any layer

---

## Naming Standardization

### Files:
- `init/setup.sh` - Init orchestration (sources core.sh, calls setup functions)
- `platform/core.sh` - Core environment setup functions
- `lib/lib.sh` - Utility functions

### Functions:
- Setup: `{platform}_setup_{component}()` - Exports environment
- Resolve: `{platform}_resolve_{resource}()` - Returns value without exporting
- Utility: `{platform}_{action}_{object}()` - Pure functions

### Variables:
- Static config: `{PLATFORM}_{CATEGORY}_{NAME}` - Set in plugin.json
- Computed environment: Set by `*_setup_*()` functions in core.sh
- Runtime state: Set by domain scripts during execution

---

## Flow Diagram

```
devbox shell
  ↓
plugin.json (env vars applied by devbox)
  ↓
init-hook.sh (pre-setup: generate config files)
  ↓
init/setup.sh
  ├─ Sources: lib/lib.sh (utilities)
  ├─ Sources: platform/core.sh (setup functions)
  └─ Calls: {platform}_setup_*() functions
      └─ Exports: SDK paths, toolchain vars, PATH
  ↓
User calls scripts (android.sh, ios.sh)
  └─ Environment already set up, ready to use
```

---

## Benefits of This Strategy

1. **Single Source of Truth:** Each variable has exactly one place where it's set
2. **Clear Responsibility:** Each layer has a well-defined purpose
3. **Testable:** Utility functions are pure and easy to test
4. **Maintainable:** Changes to environment setup are localized
5. **Consistent:** Same pattern across all platforms (Android, iOS, React Native)
