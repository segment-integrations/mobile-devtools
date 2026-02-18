# Devbox MCP Server

Model Context Protocol server for [Jetify's devbox](https://www.jetify.com/devbox) development environment tool.

## Features

- Execute devbox commands and scripts in proper environment
- List, add, search, and get info about packages
- Support for isolated environments (`--pure`)
- Environment variable management
- Timeout configuration
- Working directory support
- Automatic virtenv synchronization
- Access to devbox documentation

## Important Notes

**Always prefer devbox-mcp tools over direct Bash commands when working with devbox projects.** This ensures commands run in the correct environment with all dependencies available.

**Project structure:**
- `devbox.json` - Package and script definitions
- `devbox.d/` - Per-project configuration directory
- `.devbox/virtenv/` - Temporary runtime directory (auto-regenerated, never edit directly)

The `.devbox/virtenv/` directory is automatically regenerated on `devbox shell` or `devbox run`. Any manual changes will be lost.

## Installation

### For Claude Code

```bash
# Install via npx (recommended)
claude mcp add devbox -- npx -y devbox-mcp-server

# Or install globally first
npm install -g devbox-mcp-server
claude mcp add devbox -- devbox-mcp-server
```

### For Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "devbox": {
      "command": "npx",
      "args": ["-y", "devbox-mcp-server"]
    }
  }
}
```

## Development

This plugin includes its own devbox environment for development:

```bash
cd plugins/devbox-mcp
devbox shell
npm install

# Test the server directly
node src/index.js

# Or configure Claude Code to use local development version
claude mcp add devbox -- node "$(pwd)/src/index.js"
```

Note: `npm link` won't work in devbox environments as the Nix store is read-only. Use the direct path approach instead.

## Available Tools

### `devbox_run`
Execute devbox commands or scripts.

```typescript
devbox_run({
  command: "test:fast",              // Script or command
  args: ["--verbose"],               // Optional arguments
  pure: true,                        // Run in isolated env
  env: { DEBUG: "1" },              // Environment variables
  cwd: "/path/to/project",          // Working directory
  timeout: 300000                    // Timeout in ms
})
```

### `devbox_list`
List installed packages in current devbox environment.

### `devbox_add`
Add packages to devbox.json.

```typescript
devbox_add({
  packages: ["python@3.11", "nodejs@20"],
  cwd: "/path/to/project"
})
```

### `devbox_info`
Get information about a package.

### `devbox_search`
Search for packages in Nix registry.

### `devbox_shell_env`
Get the environment variables that would be set in a devbox shell.

### `devbox_sync`
Ensure the .devbox/virtenv/ directory is up to date by regenerating it from devbox.json.

```typescript
devbox_sync({
  cwd: "/path/to/project"
})
```

Use this after modifying devbox.json or when the virtenv may be stale.

### `devbox_init`
Initialize a new devbox.json file in the specified directory.

### `devbox_docs_search`
Search the devbox documentation for relevant information.

**Requires GitHub Authentication:** This tool uses GitHub's code search API which requires a Personal Access Token (PAT). Set one of these environment variables:
- `GITHUB_TOKEN=your_token_here`
- `GITHUB_PAT=your_token_here`

To create a token:
1. Visit https://github.com/settings/tokens
2. Create a fine-grained token with `public_repo` read access
3. Set it in your environment

If authentication isn't available, use `devbox_docs_list` to browse files, then `devbox_docs_read` to read specific docs.

```typescript
devbox_docs_search({
  query: "init hooks",
  maxResults: 10
})
```

### `devbox_docs_list`
List all available documentation files.

### `devbox_docs_read`
Read the full content of a specific documentation file.

```typescript
devbox_docs_read({
  filePath: "app/docs/devbox.mdx"
})
```

## Use Cases

- Running tests in proper devbox environment from Claude
- Managing packages without manual devbox commands
- Executing plugin scripts with correct dependencies
- Environment-aware command execution

## Requirements

- Node.js 18+ (for native fetch support)
- devbox CLI installed and in PATH (for devbox commands)
- GitHub Personal Access Token (optional, required for `devbox_docs_search`)

## License

MIT
