# segment-init Design Document

## Overview

This document provides a high-level overview of the segment-init CLI tool architecture and implementation plan.

## Architecture

The CLI follows a modular architecture with clear separation of concerns:

```
CLI Layer (main.rs, cli/)
    ↓
Configuration Layer (config/)
    ↓
Template Layer (template/)
    ↓
Transform Layer (transform/)
    ↓
Validation Layer (validation/)
```

## Key Design Decisions

### 1. Templates from examples/

**Decision:** Use `examples/` directory as canonical templates, not a separate `templates/` directory.

**Rationale:**
- Single source of truth
- Examples stay up-to-date and tested in CI
- Dogfooding: we use what users get

**Implementation:**
- Template loader reads from `../examples/{platform}/`
- File exclusion patterns filter out `.devbox/`, `tests/`, etc.
- Generated projects copy only production files

### 2. Hybrid CLI (Interactive + Flags)

**Decision:** Support both interactive prompts and flag-based invocation.

**Examples:**
```bash
# Interactive
segment-init create

# Flag-based
segment-init create my-app --name "My App" --platform android,ios
```

**Rationale:**
- Interactive: Best for first-time users
- Flags: Required for CI/CD and automation
- Flags override prompts when present

### 3. Plugin URL Rewriting

**Decision:** Parse `devbox.json` includes and rewrite `path:` to `github:` URLs.

**Examples:**
```json
// Before (in examples/)
"include": ["path:../../plugins/android/plugin.json"]

// After (in generated project)
"include": ["github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main"]
```

**Rationale:**
- Keeps examples/ with local paths for development
- Generated projects use stable GitHub refs
- Allows version pinning

### 4. Platform-Specific Transformations

**Decision:** Separate modules for Android, iOS, and React Native transforms.

**Implementation:**
- `transform/android.rs` - Updates build.gradle.kts, package structure
- `transform/ios.rs` - Updates project.pbxproj, bundle IDs
- `transform/react_native.rs` - Updates package.json, app.json

## Implementation Phases

### Phase 1: Core Infrastructure ✅ (Completed)

**Status:** Basic structure set up with unit tests

**Deliverables:**
- [x] Project structure with cargo
- [x] CLI framework with clap
- [x] Error types with thiserror
- [x] Platform enum and config types
- [x] Plugin URL rewriting logic
- [x] devbox.json parsing
- [x] Unit tests for core logic
- [x] Integration test framework

**Files Created:**
- `Cargo.toml` - Dependencies and project config
- `src/main.rs` - CLI entry point
- `src/error.rs` - Error types
- `src/cli/` - CLI handling (interactive + flags)
- `src/config/` - devbox.json and plugin management
- `src/template/` - Template types
- `src/transform/` - Transformation stubs
- `src/validation/` - Validation logic
- `tests/integration/` - Integration tests

### Phase 2: Template System (Next)

**Goal:** Load templates from examples/ and copy to output directory

**Tasks:**
- [ ] Implement template loader from filesystem
- [ ] Add file filtering (exclude patterns)
- [ ] Implement file copying with walkdir
- [ ] Handle platform-specific files
- [ ] Add tests for template loading

**Key Functions:**
```rust
fn load_template(platform: &Platform, examples_dir: &Path) -> Result<Template>
fn copy_template(template: &Template, output_dir: &Path) -> Result<()>
fn should_exclude(path: &Path) -> bool
```

### Phase 3: Project Generation

**Goal:** Generate functional project from template + config

**Tasks:**
- [ ] Rewrite plugin URLs in devbox.json
- [ ] Create output directory
- [ ] Copy template files
- [ ] Write modified devbox.json
- [ ] Basic validation

**Test:**
```rust
#[test]
fn test_generate_android_project() {
    let config = ProjectConfig { /* ... */ };
    generate_project(&config, temp_dir.path()).unwrap();
    
    assert!(temp_dir.path().join("devbox.json").exists());
    
    let devbox = read_devbox_json(temp_dir.path()).unwrap();
    assert!(devbox.include[0].starts_with("github:"));
}
```

### Phase 4: Project Renaming

**Goal:** Support custom project names, package IDs, bundle IDs

**Tasks:**
- [ ] Android: Update build.gradle.kts, package structure
- [ ] iOS: Update project.pbxproj, scheme names
- [ ] React Native: Update package.json, app.json
- [ ] Generic renaming helpers

### Phase 5: SDK Integration (Future)

**Goal:** Add Segment SDK dependencies

**Tasks:**
- [ ] Parse SDK version strings
- [ ] Modify build.gradle (Android)
- [ ] Modify Podfile (iOS)
- [ ] Modify package.json (React Native)

### Phase 6: Polish (Future)

**Goal:** Production-ready CLI

**Tasks:**
- [ ] Progress indicators
- [ ] Better error messages
- [ ] Dry-run mode
- [ ] Documentation
- [ ] Distribution

## Testing Strategy

### Unit Tests

Located inline with modules using `#[cfg(test)]`.

**Coverage:**
- Platform parsing (`cli/mod.rs`)
- Plugin URL rewriting (`config/plugins.rs`)
- devbox.json read/write (`config/devbox.rs`)
- Helper functions (naming, path manipulation)

**Run:** `cargo test`

### Integration Tests

Located in `tests/integration/`.

**Coverage:**
- CLI commands (`test_cli.rs`)
- Full project generation (future)
- Validation (future)

**Run:** `cargo test --test test_cli`

### E2E Tests (Future)

Generate projects and verify they build with devbox.

**Example:**
```bash
segment-init create test-app --platform android
cd test-app
devbox run build  # Should succeed
```

## Technical Decisions

### Rust Crates

**CLI:**
- `clap` - Command-line parsing (derive API)
- `inquire` - Interactive prompts

**Data:**
- `serde` / `serde_json` - JSON serialization
- `toml` - Config file support (optional)

**Files:**
- `walkdir` - Directory traversal
- `regex` - Pattern matching for transforms

**Errors:**
- `anyhow` - General error handling
- `thiserror` - Custom error types

**Testing:**
- `tempfile` - Temporary directories
- `assert_cmd` - CLI testing
- `assert_fs` - Filesystem assertions

### Error Handling

**Strategy:** Use `Result<T, SegmentInitError>` everywhere.

**Error Types:**
```rust
pub enum SegmentInitError {
    TemplateNotFound(String),
    InvalidPlatform(String),
    DevboxJsonParse(serde_json::Error),
    PluginRewrite(String),
    ValidationFailed(String),
    DirectoryExists(String),
    MissingField(String),
    Io(std::io::Error),
}
```

### Plugin URL Format

**GitHub URL Structure:**
```
github:{owner}/{repo}?dir={plugin_path}&ref={version}

Examples:
- github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main
- github:segment-integrations/mobile-devtools?dir=plugins/android&ref=v0.1.0
- github:segment-integrations/mobile-devtools?dir=plugins/android&ref=abc123
```

### File Exclusions

**Patterns to exclude when copying templates:**
```rust
const EXCLUDE_PATTERNS: &[&str] = &[
    ".devbox/",         // Runtime directory
    "devbox.d/",        // Generated config
    "node_modules/",    // Dependencies
    "build/",           // Build artifacts
    ".gradle/",         // Gradle cache
    "Pods/",            // CocoaPods
    "DerivedData/",     // Xcode
    "reports/",         // Test reports
    "tests/",           // Example tests
    ".git/",            // Git metadata
    "devbox.lock",      // Will be regenerated
];
```

## Future Enhancements

### Template Versioning

Support different template versions:
```bash
segment-init create --template-version v1.0.0
```

### Custom Templates

Allow users to provide custom templates:
```bash
segment-init create --template path/to/template
segment-init create --template github:user/repo?dir=templates/mobile
```

### Incremental Updates

Update existing projects:
```bash
segment-init update --plugins  # Update plugin refs
segment-init add-destination amplitude  # Add destination
```

### Configuration Profiles

Save and reuse configurations:
```bash
segment-init create --profile mobile-analytics
segment-init save-profile mobile-analytics
```

### Code Generation

Generate SDK initialization code:
```bash
segment-init create --generate-init-code
```

This would create:
- Android: Application class with Segment setup
- iOS: AppDelegate with Segment setup
- React Native: index.js with Segment setup

## Links

- [Implementation Plan](../wiki/project/SEGMENT-INIT-PLAN.md) (from Agent)
- [Examples Directory](../examples/)
- [Plugin Directory](../plugins/)
- [Cargo.toml](./Cargo.toml)
- [README](./README.md)
