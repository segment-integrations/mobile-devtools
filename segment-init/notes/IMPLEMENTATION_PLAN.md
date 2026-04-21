# Implementation Plan: Rust CLI for Reproducible Segment Projects

**Generated:** 2026-04-21  
**Tool:** segment-init  
**Purpose:** Scaffold reproducible Segment mobile projects using mobile-devtools templates

---

## Executive Summary

This plan outlines the design and implementation of a Rust CLI tool (`segment-init`) that scaffolds reproducible Segment mobile projects using the mobile-devtools infrastructure. The tool will use the examples/ directory as canonical templates, modify configurations based on user choices, and rewrite plugin references from relative paths to GitHub URLs.

## Architecture Overview

The CLI tool follows a modular architecture with clear separation of concerns:

```
segment-init/
├── Cargo.toml
├── src/
│   ├── main.rs              # Entry point, CLI argument parsing
│   ├── lib.rs               # Library exports
│   ├── cli/
│   │   ├── mod.rs           # CLI module
│   │   ├── interactive.rs   # Interactive prompts (inquire crate)
│   │   └── flags.rs         # Flag-based CLI (clap crate)
│   ├── template/
│   │   ├── mod.rs           # Template management
│   │   ├── loader.rs        # Template loading from examples/
│   │   ├── copier.rs        # File copying and filtering
│   │   └── types.rs         # Template metadata types
│   ├── config/
│   │   ├── mod.rs           # Configuration management
│   │   ├── devbox.rs        # devbox.json manipulation
│   │   ├── plugins.rs       # Plugin URL rewriting
│   │   └── sdk.rs           # SDK version management
│   ├── transform/
│   │   ├── mod.rs           # Project transformation
│   │   ├── rename.rs        # Project/package renaming
│   │   ├── android.rs       # Android-specific transforms
│   │   ├── ios.rs           # iOS-specific transforms
│   │   └── react_native.rs  # React Native transforms
│   ├── validation/
│   │   ├── mod.rs           # Validation logic
│   │   ├── checker.rs       # Post-generation validation
│   │   └── requirements.rs  # System requirements checking
│   └── error.rs             # Centralized error handling
├── tests/
│   ├── integration/
│   │   ├── test_android.rs
│   │   ├── test_ios.rs
│   │   └── test_react_native.rs
│   └── fixtures/            # Test fixtures
└── templates/               # Optional: metadata about templates
    └── manifest.json        # Template registry
```

---

## Design Decisions

### 1. CLI UX: Hybrid Approach (Interactive + Flag-based)

**Decision:** Support both interactive and flag-based modes, with flags skipping prompts.

**Rationale:**
- Interactive mode: Best for first-time users, guided experience
- Flag-based mode: Essential for CI/CD, automation, scripting
- Flags override prompts: If all required flags present, skip interactive mode entirely

**Implementation:**
```rust
// Flags take precedence
segment-init create --name MyApp --platform android,ios --sdk analytics-ios@5.0.0

// Interactive mode (no flags or partial flags)
segment-init create
? Project name: MyApp
? Platforms (space to select): [x] Android [x] iOS [ ] React Native
? Segment SDK version: analytics-ios 5.0.0
```

### 2. Template Structure: Use Examples Directly

**Decision:** Use examples/ directory as canonical templates, no separate template/ directory.

**Rationale:**
- Single source of truth: Examples stay up-to-date and testable
- Dogfooding: We use what users get
- Simpler maintenance: One codebase, not two
- CI integration: Examples already tested in CI

**Template Discovery:**
```rust
// Load templates from embedded or filesystem
let templates = TemplateRegistry::from_path("examples/")?;
// Or embed at compile time
let templates = TemplateRegistry::embedded()?;
```

**Trade-off:** CLI must handle example-specific files (test/, devbox.d/, etc.) and filter appropriately.

### 3. Plugin Management: GitHub URL Rewriting

**Decision:** Parse devbox.json includes and rewrite `path:` to `github:` URLs.

**Rationale:**
- Preserves examples/ with local paths for development
- Generated projects use stable GitHub references
- Allows version pinning via `ref=` parameter

**Implementation Strategy:**
```rust
// Transform
"include": ["path:../../plugins/android/plugin.json"]
// To
"include": ["github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main"]

// Configurable ref (tag, branch, commit)
--plugin-ref v0.1.0  // Uses tag
--plugin-ref main    // Uses branch (default)
--plugin-ref abc123  // Uses commit
```

### 4. Configuration Format: Direct devbox.json Manipulation

**Decision:** Modify devbox.json directly, no separate config file.

**Rationale:**
- devbox.json is the source of truth for Devbox projects
- No configuration drift between segment.json and devbox.json
- Users understand one format, not two
- Simpler implementation

**Approach:**
- Parse JSON with serde_json
- Manipulate structure (add/remove plugins, set env vars)
- Pretty-print with consistent formatting
- Preserve comments via strategic parsing (if needed)

### 5. SDK and Destination Plugin Management

**Decision:** Phase 1 focuses on platform plugins only; Phase 2 adds Segment SDK integration.

**Rationale:**
- Platform plugins (android, ios, react-native) are core infrastructure
- Segment SDK integration requires dependency management (Gradle, CocoaPods, npm)
- Destination plugins (Amplitude, Braze) depend on SDK integration
- Phased approach reduces complexity

**Future Design:**
```rust
// Phase 2: SDK integration
--sdk analytics-android:5.0.0
--destination amplitude,braze

// This would modify:
// - build.gradle (Android)
// - Podfile (iOS)
// - package.json (React Native)
```

### 6. Testing Strategy

**Decision:** Multi-layered testing with integration tests that build generated projects.

**Approach:**

**Unit Tests:**
- Template loading and filtering
- JSON parsing and manipulation
- Path rewriting logic
- Rename transformations

**Integration Tests:**
```rust
#[test]
fn test_android_project_generation() {
    let output_dir = TempDir::new()?;
    
    let config = ProjectConfig {
        name: "TestApp",
        platform: Platform::Android,
        plugin_ref: "main",
        package_id: Some("com.test.app"),
    };
    
    generate_project(&config, output_dir.path())?;
    
    // Verify structure
    assert!(output_dir.path().join("devbox.json").exists());
    assert!(output_dir.path().join("app/build.gradle.kts").exists());
    
    // Verify content
    let devbox = read_devbox_json(output_dir.path())?;
    assert!(devbox.include[0].starts_with("github:"));
    
    // Verify builds
    let build_result = Command::new("devbox")
        .args(&["run", "build"])
        .current_dir(output_dir.path())
        .output()?;
    assert!(build_result.status.success());
}
```

**Validation Tests:**
- Generated projects must pass `devbox run doctor`
- Generated projects must build successfully
- Generated projects must pass lint checks

---

## Implementation Phases

### Phase 1: Core Infrastructure ✅ (Week 1-2)

**Goal:** Basic project generation with single platform support

**Status:** COMPLETED

**Tasks:**
- [x] Set up Rust project with dependencies (clap, serde_json, inquire, anyhow, thiserror)
- [x] Implement template loader (filesystem and embedded options)
- [x] Implement devbox.json parser and manipulator
- [x] Implement plugin URL rewriting logic
- [x] Create basic Android project generator
- [x] Add integration test for Android

**Deliverables:**
- CLI can generate Android project from examples/android/
- Plugin paths rewritten to GitHub URLs
- Basic validation (files exist, JSON valid)

### Phase 2: Multi-Platform Support (Week 3)

**Goal:** Support all three platforms with platform selection

**Tasks:**
- [ ] Implement template file copying with exclusion patterns
- [ ] Implement iOS template handling
- [ ] Implement React Native template handling
- [ ] Add platform selection (interactive + flags)
- [ ] Implement platform-specific file filtering
- [ ] Add integration tests for iOS and React Native

**Deliverables:**
- CLI supports --platform android,ios,react-native
- Interactive mode with platform selection
- All three platforms generate correctly

**Key Functions to Implement:**
```rust
pub fn copy_template(
    template: &Template,
    output_dir: &Path,
    exclude_patterns: &[&str],
) -> Result<()>

pub fn should_exclude(path: &Path, patterns: &[&str]) -> bool

pub fn generate_project(
    config: &ProjectConfig,
    output_dir: &Path,
) -> Result<()>
```

### Phase 3: Project Renaming (Week 4)

**Goal:** Rename projects, packages, and bundle IDs

**Tasks:**
- [ ] Implement Android transformations:
  - Update applicationId in build.gradle.kts
  - Update namespace
  - Rename package directories
  - Update Java/Kotlin package declarations
  - Update strings.xml app_name
- [ ] Implement iOS transformations:
  - Update PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj
  - Update PRODUCT_NAME
  - Rename scheme
- [ ] Implement React Native transformations:
  - Update package.json name/displayName
  - Update app.json
  - Update Android package ID
  - Update iOS bundle ID
  - Rename workspace/schemes

**Deliverables:**
- `--name` flag renames project appropriately
- `--package-id` (Android) and `--bundle-id` (iOS) work correctly
- Generated projects build with new names

**Implementation Examples:**

**Android Transformation:**
```rust
pub fn rename_android_project(
    project_dir: &Path,
    old_name: &str,
    new_name: &str,
    new_package: &str,
) -> Result<()> {
    // 1. Update build.gradle.kts
    update_gradle_config(project_dir, new_package)?;
    
    // 2. Rename package directory structure
    rename_package_dirs(project_dir, new_package)?;
    
    // 3. Update package declarations in source files
    update_package_declarations(project_dir, new_package)?;
    
    // 4. Update strings.xml
    update_strings_xml(project_dir, new_name)?;
    
    // 5. Update settings.gradle.kts rootProject.name
    update_settings_gradle(project_dir, new_name)?;
    
    Ok(())
}
```

**iOS Transformation (Regex-based):**
```rust
fn update_pbxproj(
    pbxproj_path: &Path,
    old_bundle: &str,
    new_bundle: &str,
) -> Result<()> {
    let content = fs::read_to_string(pbxproj_path)?;
    let re = Regex::new(&format!(
        r#"PRODUCT_BUNDLE_IDENTIFIER = {};"#,
        regex::escape(old_bundle)
    ))?;
    
    let updated = re.replace_all(
        &content,
        format!(r#"PRODUCT_BUNDLE_IDENTIFIER = {};"#, new_bundle)
    );
    
    fs::write(pbxproj_path, updated.as_bytes())?;
    Ok(())
}
```

### Phase 4: SDK Version Management (Week 5)

**Goal:** Support SDK version selection

**Tasks:**
- [ ] Research Segment SDK integration patterns:
  - Maven coordinates for Android
  - CocoaPods specs for iOS
  - npm packages for React Native
- [ ] Implement dependency injection:
  - Modify build.gradle dependencies
  - Modify Podfile
  - Modify package.json
- [ ] Add `--sdk` flag with version parsing
- [ ] Create SDK version registry/manifest

**Deliverables:**
- `--sdk analytics-android:5.0.0` adds dependency
- Multiple SDKs can be specified
- Version validation

**SDK Registry Example:**
```rust
pub struct SdkRegistry {
    sdks: HashMap<String, SdkInfo>,
}

pub struct SdkInfo {
    name: String,
    platforms: Vec<Platform>,
    latest_version: String,
    android_coordinate: Option<String>,  // "com.segment.analytics.android:analytics:4.+"
    ios_pod: Option<String>,              // "Analytics"
    npm_package: Option<String>,          // "@segment/analytics-react-native"
}
```

### Phase 5: Destination Plugins (Week 6)

**Goal:** Add destination plugin support

**Tasks:**
- [ ] Create destination plugin registry
- [ ] Implement plugin addition to SDKs:
  - Android: Add Gradle dependencies
  - iOS: Add Podfile dependencies
  - React Native: Add npm dependencies + native linking
- [ ] Add `--destination` flag
- [ ] Generate initialization code snippets

**Deliverables:**
- `--destination amplitude,braze` adds plugins
- Plugin dependencies correctly added
- Documentation generated for initialization

### Phase 6: Polish & Documentation (Week 7)

**Goal:** Production-ready CLI

**Tasks:**
- [ ] Add progress indicators and better UX
- [ ] Implement comprehensive validation
- [ ] Add `--dry-run` flag
- [ ] Write user documentation
- [ ] Add error recovery
- [ ] Performance optimization
- [ ] Add telemetry (opt-in)

**Deliverables:**
- Polished CLI with excellent UX
- Comprehensive documentation
- Published to crates.io or distributed as binary

---

## Technical Implementation Details

### Template File Filtering

**Strategy:** Smart copying with exclusion patterns

```rust
const EXCLUDE_PATTERNS: &[&str] = &[
    ".devbox/",
    "devbox.d/",
    "node_modules/",
    "build/",
    ".gradle/",
    "Pods/",
    "DerivedData/",
    "reports/",
    "tests/",          // Example tests, not user tests
    ".git/",
    "devbox.lock",     // Will be regenerated
];

const TEMPLATE_PATTERNS: &[&str] = &[
    "devbox.json",
    "**/*.gradle",
    "**/*.kts",
    "**/*.pbxproj",
    "**/*.swift",
    "**/*.kt",
    "**/*.java",
    "**/*.xml",
    "package.json",
    "app.json",
];
```

### Plugin URL Rewriting

**Implementation:**
```rust
pub fn rewrite_plugin_urls(
    devbox_json: &mut DevboxConfig,
    repo: &str,
    ref_name: &str,
) -> Result<()> {
    for include in &mut devbox_json.include {
        if let Some(path) = include.strip_prefix("path:") {
            // Parse: path:../../plugins/android/plugin.json
            let plugin_dir = extract_plugin_dir(path)?;
            
            // Convert to: github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main
            *include = format!(
                "github:{}?dir={}&ref={}",
                repo,
                plugin_dir,
                ref_name
            );
        }
    }
    Ok(())
}

fn extract_plugin_dir(path: &str) -> Result<String> {
    // path:../../plugins/android/plugin.json -> plugins/android
    let path = Path::new(path);
    let components: Vec<_> = path.components()
        .filter(|c| !matches!(c, Component::ParentDir | Component::CurDir))
        .collect();
    
    // Take all but last (plugin.json)
    let dir = components[..components.len()-1]
        .iter()
        .map(|c| c.as_os_str().to_string_lossy())
        .collect::<Vec<_>>()
        .join("/");
    
    Ok(dir)
}
```

### Validation & Post-Generation Checks

```rust
pub fn validate_project(project_dir: &Path) -> Result<ValidationReport> {
    let mut report = ValidationReport::new();
    
    // Check required files exist
    report.check_file_exists(project_dir.join("devbox.json"))?;
    
    // Validate devbox.json is valid JSON
    let devbox_json = read_devbox_json(project_dir)?;
    report.check_devbox_config(&devbox_json)?;
    
    // Verify plugin URLs are rewritten
    for include in &devbox_json.include {
        if include.starts_with("path:") {
            report.add_error("Plugin path not rewritten to GitHub URL");
        }
    }
    
    // Platform-specific validation
    if has_android(project_dir) {
        report.validate_android(project_dir)?;
    }
    
    if has_ios(project_dir) {
        report.validate_ios(project_dir)?;
    }
    
    // Optional: Run devbox doctor
    if cfg!(feature = "integration-validation") {
        report.run_devbox_doctor(project_dir)?;
    }
    
    Ok(report)
}
```

---

## CLI Design

### Command Structure

```bash
segment-init create [OPTIONS] [PATH]

# Interactive mode
segment-init create

# Flag-based mode
segment-init create my-app \
  --name "My Segment App" \
  --platform android,ios \
  --package-id com.mycompany.app \
  --bundle-id com.mycompany.app \
  --plugin-ref v0.1.0 \
  --sdk analytics-android:5.0.0

# Minimal
segment-init create my-app --platform react-native

# List available options
segment-init list-sdks
segment-init list-destinations
segment-init list-templates

# Validate existing project
segment-init validate [PATH]

# Update plugin references in existing project
segment-init update-plugins [PATH] --ref v0.2.0
```

### Flags

```
--name <NAME>                Project name (shown to users)
--platform <PLATFORMS>       Comma-separated: android,ios,react-native
--package-id <ID>            Android package ID (e.g., com.example.app)
--bundle-id <ID>             iOS bundle ID
--plugin-ref <REF>           Plugin version (tag, branch, or commit)
--sdk <SDK:VERSION>          Segment SDK (can be specified multiple times)
--destination <DEST>         Destination plugins (comma-separated)
--no-interactive             Disable prompts (fail if required flags missing)
--dry-run                    Show what would be generated without creating files
--overwrite                  Overwrite existing directory
--git-init                   Initialize git repository
-v, --verbose                Verbose output
```

### Interactive Prompts

```
? Project name: › My Segment App
? Output directory: › ./my-segment-app
? Select platforms (space to select):
  [x] Android
  [x] iOS
  [ ] React Native
  
? Android package ID: › com.example.mysegmentapp
? iOS bundle ID: › com.example.mysegmentapp

? Select Segment SDKs:
  [ ] analytics-android
  [ ] analytics-ios
  [x] analytics-react-native
  
? Select destinations (space to select):
  [x] Amplitude
  [ ] Braze
  [ ] Firebase
  [x] Mixpanel
  
? Plugin reference (version): › main
  
✓ Project created successfully!

Next steps:
  cd my-segment-app
  devbox shell
  devbox run build
```

---

## Error Handling

**Strategy:** Use Rust's Result/anyhow for error propagation, thiserror for custom errors.

```rust
#[derive(Debug, thiserror::Error)]
pub enum SegmentInitError {
    #[error("Template not found: {0}")]
    TemplateNotFound(String),
    
    #[error("Invalid platform: {0}")]
    InvalidPlatform(String),
    
    #[error("Failed to parse devbox.json: {0}")]
    DevboxJsonParse(#[from] serde_json::Error),
    
    #[error("Failed to rewrite plugin URL: {0}")]
    PluginRewrite(String),
    
    #[error("Project validation failed: {0}")]
    ValidationFailed(String),
    
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

pub type Result<T> = std::result::Result<T, SegmentInitError>;
```

---

## Dependency Selection

```toml
[dependencies]
clap = { version = "4.5", features = ["derive", "cargo"] }
inquire = "0.7"              # Interactive prompts
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
anyhow = "1.0"
thiserror = "1.0"
walkdir = "2.5"              # Directory traversal
regex = "1.10"
toml = "0.8"                 # Optional config file support
indicatif = "0.17"           # Progress bars
colored = "2.1"              # Colored output
tempfile = "3.10"            # Testing

[dev-dependencies]
assert_cmd = "2.0"           # CLI testing
predicates = "3.1"           # Assertions
assert_fs = "1.1"            # Filesystem assertions
```

---

## Distribution Strategy

### Option 1: Cargo Install
```bash
cargo install segment-init
```

### Option 2: Precompiled Binaries
- GitHub Releases with binaries for Linux, macOS, Windows
- Distribute via Homebrew, apt, etc.

### Option 3: Embedded in Devbox
- Include as part of mobile-devtools repository
- Distribute with devbox plugin

**Recommendation:** Start with Option 1, add Option 2 for broader adoption.

---

## Open Questions & Future Enhancements

1. **Template Versioning:** How to handle template version compatibility?
   - Suggestion: Embed template version in manifest, check compatibility

2. **Incremental Updates:** Support updating existing projects?
   - `segment-init update --plugins` to update plugin refs
   - `segment-init add-destination amplitude`

3. **Custom Templates:** Allow users to provide custom templates?
   - Support `--template path/to/template` or `--template github:user/repo`

4. **Configuration Profiles:** Save and reuse project configurations?
   - `segment-init create --profile mobile-analytics`

5. **CI/CD Integration:** Generate CI config files?
   - GitHub Actions workflows
   - GitLab CI
   - Jenkins

6. **Code Generation:** Generate SDK initialization code?
   - Android: Application class setup
   - iOS: AppDelegate setup
   - React Native: index.js setup

---

## Trade-offs & Technical Decisions Summary

| Decision | Trade-off | Rationale |
|----------|-----------|-----------|
| **Use examples/ as templates** | Examples must stay clean | Single source of truth, easier maintenance |
| **Hybrid CLI (interactive + flags)** | More code complexity | Better UX for both novices and automation |
| **Direct devbox.json manipulation** | No separate config format | Simpler mental model, no drift |
| **Phase SDK integration** | Delayed SDK support | Focus on core functionality first |
| **Regex for Xcode projects** | Less precise than full parsing | Pragmatic, covers 95% of cases |
| **Rust implementation** | Smaller ecosystem than Node | Performance, type safety, single binary |

---

## Success Criteria

**Phase 1:** ✅
- Generate Android project that builds with `devbox run build`
- Plugin URLs correctly rewritten to GitHub

**Phase 3:**
- All three platforms (Android, iOS, React Native) generate correctly
- Project renaming works (name, package ID, bundle ID)
- Generated projects pass `devbox run doctor`

**Phase 6:**
- Published CLI with documentation
- Integration tests cover all platforms
- Users can generate production-ready projects in <2 minutes

---

## Critical Files for Implementation

Based on exploration, the following files are most critical for implementing this CLI tool:

- `/Users/abueide/code/mobile-devtools/examples/android/devbox.json`
- `/Users/abueide/code/mobile-devtools/examples/ios/devbox.json`
- `/Users/abueide/code/mobile-devtools/examples/react-native/devbox.json`
- `/Users/abueide/code/mobile-devtools/plugins/react-native/plugin.json`
- `/Users/abueide/code/mobile-devtools/examples/android/app/build.gradle.kts`

---

## References

- [DESIGN.md](../DESIGN.md) - Architecture overview
- [README.md](../README.md) - User guide
- [Cargo.toml](../Cargo.toml) - Dependencies
- [Examples Directory](../../examples/) - Source templates
- [Plugins Directory](../../plugins/) - Plugin sources
