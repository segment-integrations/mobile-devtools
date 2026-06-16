# Contributing

This document defines how we structure commits and pull requests in this repository.
For architecture, plugin conventions, and platform-specific guidance see `CLAUDE.md`,
`plugins/CONVENTIONS.md`, and the `wiki/` docs.

## Commit format

```
<type>(<scope>): <summary> (<epic>)
```

Every commit declares exactly one `<type>`, names the `<scope>` it touches, and references the
`<epic>` (or task) it belongs to. One commit is one kind of change — never mix types.

Example:

```
feat(segkit): add leveled logger with color and file output (MVP-0.1)
```

### Type — exactly one per commit

| Type    | Use for                                                                       |
| ------- | ----------------------------------------------------------------------------- |
| `feat`  | New behavior or capability.                                                   |
| `bug`   | A fix for incorrect behavior.                                                 |
| `docs`  | Documentation only (Markdown, REFERENCE files, comments, task lists).         |
| `tests` | Test code only (new tests, fixtures, harness wiring) with no behavior change. |
| `gen`   | Generated or mechanical churn — see below.                                    |

These map onto the conventional-commit types referenced in `CLAUDE.md`: `bug` is `fix`,
`tests` is `test`, and `gen` is new. We do not use `refactor`/`perf`/`chore` as top-level
types — a refactor that changes no behavior is `feat` or `bug` depending on intent, and
mechanical churn is `gen`.

### `gen` — isolate the noise

Generated and mechanical changes go in their own `gen` commits, separated from hand-written
work, so reviewers can skim them with confidence instead of auditing them line by line. This
includes:

- Formatting-only changes (`treefmt`, `cargo fmt`, `gofmt`, prettier).
- Lock files (`Cargo.lock`, `package-lock.json`, `Podfile.lock`, `devbox.lock`, `devices.lock`).
- Scaffolder/codegen output and other regenerated artifacts.

A `gen` commit's summary must say plainly what produced it, e.g.
`gen(segkit): cargo fmt (MVP-0.1)` or `gen(rn): regenerate package-lock after dep bump`.
Never fold a `gen` change into a `feat`/`bug` commit — if a code change forces a reformat or a
lock-file update, split the mechanical part into a trailing `gen` commit.

### Scope

The area of the repo the commit touches: `segkit`, `android`, `ios`, `react-native` (or `rn`),
`ci`, `docs`, `tests`, `examples`. Use the narrowest scope that fits.

### Epic reference

Reference the epic or task somewhere in the title, in parentheses at the end:
`(MVP-0.1)`, `(M1.2)`, `(T3)`. This ties the commit back to `notes/segkit-milestones/`. For
work with no epic, use the issue or PR reference (`(#123)`) or omit the suffix for one-off
fixes.

## Pull requests

- **Keep each commit reviewable: under ~600 lines of diff.** Split larger work into focused
  commits along natural seams (module, layer, feature). Big mechanical diffs (lock files,
  generated output) don't count against the budget when isolated in their own `gen` commit —
  that is the point of isolating them.
- Order commits so the PR reads top-to-bottom: foundational changes first, then the work that
  builds on them, with `gen` and `docs` commits grouped rather than scattered.
- A PR should land one epic or one self-contained slice of one. Don't bundle unrelated epics.

## Attribution

Commits created with AI assistance end with a trailer:

```
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```
