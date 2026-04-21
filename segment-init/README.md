# segment-init

CLI tool for creating reproducible Segment mobile projects using the mobile-devtools templates.

## Features

- 🚀 Quick project scaffolding from tested templates
- 📱 Support for Android, iOS, and React Native
- 🔧 Automatic plugin URL rewriting (relative → GitHub)
- 🎨 Interactive prompts or flag-based CLI
- ✅ Built-in validation
- 📦 Uses examples/ as canonical templates

## Installation

```bash
# From source (requires Rust)
cd segment-init
cargo install --path .

# Or use directly
cargo run -- create --help
```

## Usage

### Interactive Mode

```bash
segment-init create
```

This will prompt you for:
- Project name
- Output directory
- Platform selection (Android, iOS, React Native)
- Package ID / Bundle ID
- Plugin version

### Flag-Based Mode

```bash
segment-init create my-app \
  --name "My Segment App" \
  --platform android,ios \
  --package-id com.example.myapp \
  --bundle-id com.example.myapp \
  --plugin-ref v0.1.0 \
  --git-init
```

### Other Commands

```bash
# List available SDKs
segment-init list-sdks

# List destination plugins
segment-init list-destinations

# List templates
segment-init list-templates

# Validate existing project
segment-init validate ./my-app

# Update plugin references
segment-init update-plugins ./my-app --ref v0.2.0
```

## Options

```
--name <NAME>              Project name
--platform <PLATFORMS>     Comma-separated: android,ios,react-native
--package-id <ID>          Android package ID
--bundle-id <ID>           iOS bundle ID
--plugin-ref <REF>         Plugin version (tag/branch/commit)
--no-interactive           Disable prompts
--dry-run                  Show what would be generated
--overwrite                Overwrite existing directory
--git-init                 Initialize git repository
-v, --verbose              Verbose output
```

## Development

### Project Structure

```
segment-init/
├── src/
│   ├── main.rs              # CLI entry point
│   ├── cli/                 # CLI handling
│   │   ├── interactive.rs   # Interactive prompts
│   │   └── flags.rs         # Flag parsing
│   ├── template/            # Template loading
│   ├── config/              # devbox.json manipulation
│   │   ├── devbox.rs        # Read/write operations
│   │   └── plugins.rs       # Plugin URL rewriting
│   ├── transform/           # Project transformations
│   │   ├── android.rs       # Android-specific
│   │   ├── ios.rs           # iOS-specific
│   │   └── react_native.rs  # React Native-specific
│   └── validation/          # Validation logic
└── tests/
    └── integration/         # Integration tests
```

### Running Tests

```bash
# Run all tests
cargo test

# Run specific test
cargo test test_platform_from_str

# Run with output
cargo test -- --nocapture
```

### Building

```bash
# Debug build
cargo build

# Release build
cargo build --release

# The binary will be at target/release/segment-init
```

## Implementation Plan

### Phase 1: Core Infrastructure ✅
- [x] Project setup with dependencies
- [x] Basic CLI structure with clap
- [x] Template types and error handling
- [x] devbox.json parsing
- [x] Plugin URL rewriting logic
- [x] Unit tests

### Phase 2: Template System (In Progress)
- [ ] Template loading from examples/
- [ ] File copying with exclusions
- [ ] Basic project generation

### Phase 3: Multi-Platform Support
- [ ] Android template handling
- [ ] iOS template handling
- [ ] React Native template handling
- [ ] Platform-specific file filtering

### Phase 4: Project Renaming
- [ ] Android transformations (package ID, namespace)
- [ ] iOS transformations (bundle ID, scheme)
- [ ] React Native transformations

### Phase 5: SDK Integration
- [ ] SDK version management
- [ ] Dependency injection (Gradle, Podfile, package.json)

### Phase 6: Polish
- [ ] Progress indicators
- [ ] Comprehensive validation
- [ ] Documentation
- [ ] Distribution (crates.io)

## Contributing

See the main [mobile-devtools](../) repository for contribution guidelines.

## License

MIT
