# Plugin Unit Tests

This directory contains **pure unit tests** for plugin scripts. These tests verify individual functions work correctly in isolation.

## Structure

```
plugins/tests/
├── android/
│   ├── test-lib.sh              # Tests for lib.sh utility functions
│   ├── test-devices.sh          # Tests for devices.sh CLI parsing
│   ├── test-apk-detection.sh    # Tests for APK metadata extraction
│   ├── test-apk-resolution.sh   # Tests for APK auto-detection
│   ├── test-emulator-detection.sh  # Emulator detection tests
│   └── test-emulator-modes.sh   # Emulator mode behavior docs
├── ios/
│   ├── test-lib.sh              # Tests for lib.sh utility functions
│   ├── test-devices.sh          # Tests for devices.sh CLI parsing
│   ├── test-app-resolution.sh   # Tests for .app auto-detection
│   ├── test-simulator-detection.sh  # Simulator detection tests
│   └── test-simulator-modes.sh  # Simulator mode behavior docs
├── react-native/
│   └── test-lib.sh              # Tests for Metro port management
└── test-framework.sh            # Shared test utilities
```

## Running Tests

```bash
# All plugin unit tests
devbox run test:plugin:unit

# Android plugin tests
devbox run test:plugin:android
devbox run test:plugin:android:lib
devbox run test:plugin:android:devices

# iOS plugin tests
devbox run test:plugin:ios
devbox run test:plugin:ios:lib
```

## Test Coverage

### Android (`test-lib.sh`)
- String normalization
- AVD name sanitization
- Device checksum computation
- Path resolution
- Requirement validation

### Android (`test-devices.sh`)
- Device CRUD operations (create, list, show, update, delete)
- Lock file generation
- Device filtering
- JSON file manipulation

### iOS (`test-lib.sh`)
- String normalization
- Path resolution
- Config directory resolution
- Requirement validation

### React Native (`test-lib.sh`)
- Metro port allocation and retrieval
- Metro environment file management
- PID tracking
- Suite isolation

## Test Framework

All tests source `test-framework.sh` which provides assertions, fixture helpers, and test summary reporting.

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

# Write tests
start_test "My feature"
assert_equal "expected" "$(my_function)" "Description"
assert_success "some_command" "Should succeed"
assert_failure "bad_command" "Should fail"

# Use example project fixtures for read-only tests
devices_dir="$(fixture_android_devices_dir)"

# Use project-local temp dirs for write tests
temp="$(make_temp_dir "my-test")"
# ... use temp dir ...
rm -rf "$temp"

# Show summary
test_summary "suite-name"
```

### Available Assertions

- `assert_equal expected actual message` - Value equality
- `assert_success "cmd" message` - Command succeeds (eval-based)
- `assert_failure "cmd" message` - Command fails (eval-based)
- `assert_not_empty value message` - Value is non-empty
- `assert_contains haystack needle message` - String contains substring
- `assert_output "cmd" expected message` - Command output contains string
- `assert_file_exists path message` - File exists
- `assert_file_contains path pattern message` - File contains pattern
- `assert_command_success message cmd args...` - Command succeeds (direct)

### Fixture Helpers

- `fixture_android_devices_dir` - Path to `examples/android/devbox.d/android/devices`
- `fixture_ios_devices_dir` - Path to `examples/ios/devbox.d/ios/devices`
- `make_temp_dir label` - Creates dir under `reports/tmp/` (project-local)

## Adding New Tests

1. Create test file in appropriate directory (`plugins/tests/{platform}/`)
2. Source `test-framework.sh` and call `setup_logging`
3. Use example project fixtures for read-only tests, `make_temp_dir` for write tests
4. Call `test_summary "suite-name"` at the end
5. Add command to `devbox.json` if needed

## Guidelines

- **Pure unit tests only** - Test individual functions directly
- **No /tmp/** - Use `make_temp_dir()` for project-local temp directories
- **Example fixtures** - Use `fixture_*_devices_dir()` for read-only device config tests
- **Fast execution** - All tests should run in under 30 seconds total
- **Isolated** - Tests clean up after themselves

## Related Testing

- **Integration tests**: `/tests/integration/` - Test plugin workflows
- **E2E tests**: `/tests/e2e/` - Test full application lifecycle

See `/tests/README.md` for complete testing guide.
