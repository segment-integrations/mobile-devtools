# Android Example

This is a minimal Android application demonstrating the mobile-devtools Android plugin for Devbox.

## Plugin Configuration

This example uses a **local path include** for development and testing within this repository:

```json
{
  "include": [
    "path:../../plugins/android/plugin.json"
  ]
}
```

### Using This Example Outside This Repository

If you copy this example to use as a template for your own project, you need to change the plugin include to use the GitHub URL instead:

```json
{
  "include": [
    "github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main"
  ]
}
```

The local path (`path:../../plugins/android/plugin.json`) only works within the mobile-devtools repository structure. When used outside this repo, Devbox won't be able to find the plugin files.

For more information about the Android plugin, see the [Android Plugin Reference](../../plugins/android/REFERENCE.md).

## Quick Start

```bash
# Enter devbox environment
devbox shell

# Build the app
devbox run build

# Start emulator
devbox run start:emu

# Install and launch app
devbox run start:app
```

## Device Management

```bash
# List available devices
devbox run android.sh devices list

# Create a new device
devbox run android.sh devices create pixel_api30 --api 30 --device pixel

# Sync AVDs to match device definitions
devbox run android.sh devices sync
```

## Testing

```bash
# Run unit tests
devbox run test

# Run E2E tests
devbox run test:e2e
```
