# iOS Example

This is a minimal Swift package demonstrating the mobile-devtools iOS plugin for Devbox.

## Plugin Configuration

This example uses a **local path include** for development and testing within this repository:

```json
{
  "include": [
    "path:../../plugins/ios/plugin.json"
  ]
}
```

### Using This Example Outside This Repository

If you copy this example to use as a template for your own project, you need to change the plugin include to use the GitHub URL instead:

```json
{
  "include": [
    "github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"
  ]
}
```

The local path (`path:../../plugins/ios/plugin.json`) only works within the mobile-devtools repository structure. When used outside this repo, Devbox won't be able to find the plugin files.

For more information about the iOS plugin, see the [iOS Plugin Reference](../../plugins/ios/REFERENCE.md).

## Quick Start

```bash
# Enter devbox environment
devbox shell

# Build the app
devbox run build

# Start simulator
devbox run start:sim

# Install and launch app
devbox run start:app
```

## Device Management

```bash
# List available devices
devbox run ios.sh devices list

# Create a new device
devbox run ios.sh devices create iphone15 --runtime 17.5

# Sync simulators to match device definitions
devbox run ios.sh devices sync
```

## Testing

```bash
# Run unit tests
devbox run test

# Run E2E tests
devbox run test:e2e
```
