# Segkit Multi-SDK Design

This document describes how segkit supports multiple Segment SDK examples (starting with analytics-swift and analytics-react-native) and the implementation plan to get there from the current state.

## Current State

Segkit is a thin Rust CLI (v0.1.0, ~500 lines) with three responsibilities:

1. **Delegation** — routes `segkit {ios,android,rn,metro} [args]` to platform shell scripts
2. **Doctor** — hardcoded checks for devbox, homebrew, applesimutils
3. **Telemetry** — logs command timing and errors to JSONL files

The Swift reproduction example (`examples/segment/swift/`) uses the iOS devbox plugin directly and has a standalone `scripts/share.sh` (189 lines of bash) for packaging reproductions. There is no React Native equivalent in `examples/segment/` yet.

The existing shell-based doctor scripts (in each plugin's `virtenv/scripts/`) total ~1,300 lines across Android, iOS, and React Native variants. These are the migration targets.

## Target Architecture

### segkit subcommands

```
segkit doctor [--fix] [--platform <ios|android|rn>]
segkit share [--name <archive-name>]
segkit ios <args>        # unchanged - delegates to ios.sh
segkit android <args>    # unchanged - delegates to android.sh
segkit rn <args>         # unchanged - delegates to rn.sh
segkit metro <args>      # unchanged - delegates to metro.sh
```

### segkit doctor — Composable Check Registry

The current doctor is a flat list of three checks. The new design uses a check registry with platform tags so checks compose automatically based on project context.

#### Check Model

```rust
struct Check {
    name: &'static str,
    tags: &'static [Tag],       // which contexts this check applies to
    run: fn(&DoctorCtx) -> CheckResult,
    fix: Option<fn(&DoctorCtx) -> FixResult>,
}

enum Tag {
    Global,    // always runs (devbox)
    Macos,     // macOS-only (homebrew, xcode)
    Ios,       // iOS projects (simctl, applesimutils)
    Android,   // Android projects (adb, emulator, sdk)
    Rn,        // React Native (node, watchman, metro port)
}
```

#### Context Detection

Rather than requiring the user to pass `--platform`, segkit infers which checks to run:

1. Read `devbox.json` in the current directory
2. Inspect `include` entries for plugin references (ios, android, react-native)
3. Activate tags based on detected plugins
4. `--platform` flag overrides auto-detection

This keeps devbox.json as the single source of truth (per existing UX principles).

#### Check Categories

| Tag | Checks |
|-----|--------|
| Global | devbox installed |
| Macos | homebrew installed |
| Ios | xcode CLI tools, xcrun simctl, applesimutils, ios devices configured |
| Android | ANDROID_SDK_ROOT set + exists, adb, emulator, android devices configured |
| Rn | node >= 18, npm, watchman, metro port available, package.json exists, node_modules installed, react-native dependency present |

A React Native project activates `Global + Macos + Ios + Android + Rn`. A Swift-only project activates `Global + Macos + Ios`. A Kotlin-only project activates `Global + Android`.

#### Fix Behavior

Each check can optionally provide a `fix` function. When `--fix` is passed:
- Run the check
- If it fails, attempt the fix
- Re-run the check to verify
- Report fixed/failed

Checks without a fix function report the failure with an actionable message (what command to run manually).

### segkit share — Platform-Aware Archiving

Replaces `examples/segment/swift/scripts/share.sh` with a Rust subcommand.

#### Behavior

1. Detect project type from devbox.json includes (same detection as doctor)
2. Determine archive name prefix from project directory name or `--name` override
3. Check for uncommitted changes, commit if found (with platform-appropriate message)
4. Copy project files to temp staging directory with platform-appropriate excludes
5. Generate REPRO-INFO.txt with detected platform and setup instructions
6. Create git patch of changes
7. Zip and output to `{repo-root}/shared-repros/`
8. Copy path to clipboard (macOS)

#### Platform-Specific Excludes

```rust
fn excludes_for(tags: &[Tag]) -> Vec<&str> {
    let mut excludes = vec![".git", ".devbox", ".DS_Store", "build", "node_modules"];
    if tags.contains(&Tag::Ios) {
        excludes.extend(["DerivedData", "*.xcuserstate", "xcuserdata"]);
    }
    if tags.contains(&Tag::Android) {
        excludes.extend([".gradle", "local.properties"]);
    }
    if tags.contains(&Tag::Rn) {
        excludes.extend(["ios/Pods", "android/.gradle", ".metro-*"]);
    }
    excludes
}
```

### Example Directory Structure

```
examples/segment/
├── README.md              # Multi-SDK overview (generalized)
├── swift/                 # analytics-swift reproduction
│   ├── devbox.json        # includes ios plugin
│   ├── devbox.d/ios/devices/
│   ├── ios/               # Swift source
│   └── ios.xcodeproj/
└── react-native/          # analytics-react-native reproduction
    ├── devbox.json        # includes react-native plugin
    ├── devbox.d/
    │   ├── android/devices/
    │   └── ios/devices/
    ├── src/               # RN source (TypeScript)
    ├── android/           # Native Android shell
    ├── ios/               # Native iOS shell
    └── package.json
```

Each example is self-contained. `segkit doctor` and `segkit share` work in either directory by reading the local devbox.json.

### React Native Example App

Minimal RN app demonstrating analytics-react-native SDK:
- Track, identify, screen events via UI buttons
- Console logging plugin showing all events
- Gitignored config file for write key (same pattern as Swift example)
- Devbox scripts: `build:android`, `build:ios`, `start:app` (both platforms)

## Segkit Source Structure (After)

```
segkit/src/
├── main.rs           # CLI entry point, subcommand routing
├── delegate.rs       # Script delegation (unchanged)
├── context.rs        # NEW: devbox.json parsing, tag detection
├── doctor/
│   ├── mod.rs        # Check registry, runner, output formatting
│   ├── checks/
│   │   ├── global.rs # devbox
│   │   ├── macos.rs  # homebrew
│   │   ├── ios.rs    # xcode, simctl, applesimutils, ios devices
│   │   ├── android.rs# sdk, adb, emulator, android devices
│   │   └── rn.rs     # node, npm, watchman, metro, package.json
│   └── fix.rs        # Installation logic (from current doctor.rs)
└── share/
    ├── mod.rs        # Archive creation orchestration
    ├── excludes.rs   # Platform-specific exclude lists
    └── repro_info.rs # REPRO-INFO.txt generation
```

## Implementation Plan

### Phase 1: segkit doctor refactor

Restructure the existing doctor from a flat check list into the composable registry. No new checks yet — just reorganize devbox/homebrew/applesimutils into the new structure.

Steps:
1. Add `context.rs` — parse devbox.json, extract plugin includes, return active tags
2. Create `doctor/mod.rs` with `Check` struct and registry pattern
3. Move existing checks from `doctor.rs` into `doctor/checks/global.rs` and `doctor/checks/macos.rs`
4. Wire up tag-based filtering (run only checks matching active tags)
5. Add `--platform` override flag
6. Tests: unit test context detection, integration test check filtering

### Phase 2: Expand doctor checks

Port checks from the shell-based doctor scripts into Rust.

Steps:
1. `doctor/checks/ios.rs` — xcode CLI tools, xcrun simctl, applesimutils, device config directory
2. `doctor/checks/android.rs` — ANDROID_SDK_ROOT, adb, emulator, device config directory
3. `doctor/checks/rn.rs` — node version, npm, watchman, metro port, package.json, node_modules
4. Add fix functions where applicable (applesimutils install, npm install prompt)
5. Tests for each check module (mock env vars and PATH)

### Phase 3: segkit share

Replace `share.sh` with a Rust subcommand.

Steps:
1. Add `share/mod.rs` — git status check, auto-commit, staging, zip creation
2. Add `share/excludes.rs` — platform-specific exclude lists driven by context tags
3. Add `share/repro_info.rs` — template REPRO-INFO.txt generation
4. Add `zip` crate dependency (or shell out to `zip` binary since it's already a devbox package)
5. Wire up `segkit share` in main.rs
6. Remove `examples/segment/swift/scripts/share.sh`, update devbox.json script to call `segkit share`
7. Tests: verify exclude lists per platform, verify REPRO-INFO content

### Phase 4: React Native example

Create the analytics-react-native reproduction example.

Steps:
1. `npx react-native init` a minimal app (or copy from analytics-react-native repo's example)
2. Add `@segment/analytics-react-native` dependency
3. Wire up basic track/identify/screen calls in a simple UI
4. Add console logging destination for visibility
5. Create `devbox.json` including the react-native plugin
6. Add device configs in `devbox.d/` (android min/max, ios min/max)
7. Add devbox scripts: `build:android`, `build:ios`, `start:app`, `test:e2e`
8. Verify `segkit doctor` and `segkit share` work from the new example directory
9. Update `examples/segment/README.md` to list the react-native example

### Phase 5: Clean up shell doctor scripts

Once segkit doctor covers all checks, deprecate and eventually remove the shell-based doctor scripts from the plugins. This is lower priority since the shell scripts still work and the plugins need to function without segkit for external consumers.

Steps:
1. Mark plugin doctor scripts as deprecated (point to `segkit doctor`)
2. Keep them functional for users who don't have segkit installed
3. Eventually gate on segkit presence: if segkit is in PATH, delegate; otherwise fall back to shell

## Dependencies to Add

```toml
# Cargo.toml additions
[dependencies]
zip = "2"              # archive creation (or shell out to zip binary)
walkdir = "2"          # directory traversal for share
glob = "0.3"           # pattern matching for excludes
```

## Key Design Decisions

**devbox.json is the source of truth.** No `.segkitrc` or separate config file. Project type, platform targets, and device configurations are all derived from devbox.json includes and env vars.

**Checks are tagged, not hierarchical.** A check can have multiple tags (`[Ios, Macos]`). A project activates a set of tags. This is simpler than a dependency tree and handles the "RN shares Android checks with Kotlin" case naturally — both activate the `Android` tag.

**Fix is opt-in per check.** Not every check can be auto-fixed (you can't auto-install Xcode). Checks declare whether they support `--fix`. The runner handles the try/verify/report cycle.

**Shell scripts remain for delegation.** The ios.sh/android.sh/rn.sh scripts handle complex domain logic (AVD management, emulator lifecycle, simulator control). Porting those is a separate, larger effort tracked in migration-status.json. Segkit's job is to be the user-facing entry point and handle cross-cutting concerns (doctor, share, telemetry).
