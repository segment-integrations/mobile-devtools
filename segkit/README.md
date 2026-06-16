# segkit

Segment SDK developer toolkit. A Rust CLI that wraps the Devbox plugin scripts
(`android.sh`, `ios.sh`, `rn.sh`, `metro.sh`) and provides project scaffolding,
configuration, and environment management.

Build and test through Devbox from the repo root:

```bash
devbox run segkit:build    # cargo build
devbox run segkit:test     # cargo test
devbox run segkit:check    # fmt check + clippy + test
```

## Logging

segkit logs at four levels — `debug`, `info`, `warn`, `error` — using the same
`[LEVEL] [segkit] message` prefix as the shell plugins, so interleaved CI output
reads uniformly across Rust and shell.

`debug` is suppressed unless `SEGKIT_DEBUG=1` (or the global `DEBUG=1`), mirroring
the shell `*_DEBUG` flags:

```bash
SEGKIT_DEBUG=1 segkit rn doctor    # shows [DEBUG] delegation traces
```

### Output sinks

Logs are diagnostics, not program output, so they go to stderr — leaving stdout
clean for data you might pipe or capture (e.g. `config show`). Every log line is
written to two places:

- **stderr**, with the `[LEVEL]` tag color-coded by level (gray/blue/yellow/red)
  when stderr is a terminal. Color is suppressed automatically when output is
  piped or redirected, or when [`NO_COLOR`](https://no-color.org/) is set.
- **`${REPORTS_DIR:-reports}/segkit.log`**, appended across runs and never
  colored, so it accumulates a historical log that CI can upload as a job
  artifact. `REPORTS_DIR` is the same reports root the delegation timing/error
  logs use.

The file sink is plain text by construction — ANSI color codes only ever reach a
terminal, never the log file.

Subprocesses segkit spawns (emulator, simulator, the SDK example, process-compose)
inherit segkit's streams: their stdout and stderr pass through unchanged, so their
own diagnostics stay on stderr and their data stays on stdout.
