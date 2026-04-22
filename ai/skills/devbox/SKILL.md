# Devbox CLI Usage and Project Structure

## Overview

Devbox creates isolated, reproducible development environments using Nix packages. Dependencies are defined in `devbox.json` and version-locked.

## Core Commands

### devbox run

Executes commands/scripts in devbox environment. Can run any binary in PATH, not just scripts in devbox.json.

```bash
devbox run test                      # Script from devbox.json
devbox run python script.py          # Any binary
devbox run --pure test               # Isolated (no system PATH)
devbox run --list                    # List available scripts
devbox run -c alt.json test          # Use alternate config
devbox run --cwd /path test          # Change working directory
devbox run -e DEBUG=1 test           # Set environment variable
```

WARNING: `devbox shell -c "command"` does NOT execute commands. The `-c` flag specifies config file path. Use `devbox run command` instead.

### devbox shell

Starts interactive shell with packages available. Use for manual exploration, not automation.

```bash
devbox shell                         # Enter shell
devbox shell --pure                  # Isolated shell
```

### devbox add/rm

```bash
devbox add python@3.11 nodejs@20     # Add packages
devbox rm python                     # Remove package
devbox list                          # List packages
```

### devbox search/info

```bash
devbox search postgresql             # Search packages
devbox info python                   # Package details
```

### Other

```bash
devbox init                          # Create devbox.json
devbox update                        # Update packages
devbox shell-env                     # Show environment variables
```

## Flags

**--pure**: Isolates from system PATH. Use in CI/CD for reproducibility.

**--config / -c**: Specifies alternate devbox.json (NOT for command execution like bash).

**--cwd**: Changes working directory.

**--env / -e**: Sets environment variables.

## Project Structure

### devbox.json

Main configuration file. Defines packages, env vars, scripts, plugins.

```json
{
  "packages": ["python@3.11", "nodejs@20"],
  "env": {
    "VAR": "value"
  },
  "shell": {
    "init_hook": "echo 'initialized'",
    "scripts": {
      "test": "pytest",
      "build": "npm run build"
    }
  },
  "include": [
    "plugin:path/to/plugin.json",
    "github:org/repo?dir=plugins/name"
  ]
}
```

### .devbox/

Generated directory. DO NOT EDIT. Contains nix derivations and runtime state. Add to .gitignore.

### .devbox/virtenv/

Temporary runtime directory. Auto-regenerated on `devbox shell` or `devbox run`.

CRITICAL: Never edit files here. Changes will be lost. For plugin development, edit source files and sync.

### devbox.d/

Per-project configuration for plugins. Directory names:
- Local includes: `devbox.d/plugin-name/`
- GitHub includes: `devbox.d/org.repo.plugin-name/`

### plugin.json

Plugin manifest (plugin authors only). Defines hooks, env vars, files to copy.

## Environment Variables

Core variables available in devbox environment:

- `DEVBOX_PROJECT_ROOT` - Project root directory (where devbox.json is)
- `DEVBOX_PACKAGES_DIR` - Installed packages directory
- `DEVBOX_VIRTENV` - Path to .devbox/virtenv/
- `DEVBOX_PLUGIN_DIR` - Plugin directory (in plugin hooks)

Custom variables set in devbox.json `env` section.

## Common Workflows

### New Project

```bash
devbox init
devbox add python@3.11 nodejs@20
# Edit devbox.json to add scripts
devbox run test
```

### Existing Project

```bash
git clone <repo>
cd <repo>
devbox shell  # or devbox run <command>
```

### Plugin Usage

Local plugin (development):
```json
{"include": ["plugin:../../plugins/name/plugin.json"]}
```

GitHub plugin (distribution):
```json
{"include": ["github:org/repo?dir=plugins/name"]}
```

### Reproducible Builds

Always use --pure in CI/CD:
```bash
devbox run --pure build
devbox run --pure test
```

## Quick Reference

| Task | Command |
|------|---------|
| Run script | `devbox run <name>` |
| Run command | `devbox run <cmd> [args]` |
| Isolated run | `devbox run --pure <cmd>` |
| Interactive shell | `devbox shell` |
| Add package | `devbox add <pkg>` |
| Remove package | `devbox rm <pkg>` |
| List packages | `devbox list` |
| List scripts | `devbox run --list` |
| Show env | `devbox shell-env` |
| Initialize | `devbox init` |
| Search packages | `devbox search <query>` |

## Key Points

- Use `devbox run` for commands, not `devbox shell -c`
- Never edit .devbox/ or .devbox/virtenv/ directly
- Use --pure for reproducible builds
- Scripts in devbox.json are shortcuts; `devbox run` can execute any binary
- .devbox/ should be in .gitignore
