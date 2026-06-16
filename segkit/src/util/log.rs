//! Leveled logger mirroring the shell side's `[LEVEL] [script] message` contract.
//!
//! Logs are diagnostics, so they go to stderr (color-coded by level when stderr
//! is a terminal), leaving stdout for the program's actual data. Every line is
//! also appended, uncolored, to `${REPORTS_DIR:-reports}/segkit.log` so CI can
//! upload a historical log as an artifact. `debug` is emitted only when
//! `SEGKIT_DEBUG=1` or `DEBUG=1`, matching the shell `*_DEBUG` flags.

use std::fs::OpenOptions;
use std::io::{IsTerminal, Write};

const TAG: &str = "segkit";

#[derive(Clone, Copy)]
enum Level {
    Debug,
    Info,
    Warn,
    Error,
}

impl Level {
    fn label(self) -> &'static str {
        match self {
            Level::Debug => "DEBUG",
            Level::Info => "INFO",
            Level::Warn => "WARN",
            Level::Error => "ERROR",
        }
    }

    /// ANSI color for the `[LEVEL]` tag: debug=gray, info=blue, warn=yellow, error=red.
    fn color(self) -> &'static str {
        match self {
            Level::Debug => "\x1b[1;90m",
            Level::Info => "\x1b[1;34m",
            Level::Warn => "\x1b[1;33m",
            Level::Error => "\x1b[1;31m",
        }
    }
}

const RESET: &str = "\x1b[0m";

/// Uncolored log line, e.g. `[INFO] [segkit] message`. Written to the log file.
fn plain_line(level: Level, msg: &str) -> String {
    format!("[{}] [{}] {}", level.label(), TAG, msg)
}

/// Colored log line for a terminal: only the `[LEVEL]` tag is wrapped in ANSI.
fn colored_line(level: Level, msg: &str) -> String {
    format!(
        "{}[{}]{} [{}] {}",
        level.color(),
        level.label(),
        RESET,
        TAG,
        msg
    )
}

/// Whether `debug` output is enabled, given an env lookup. Mirrors the shell
/// contract: on when `SEGKIT_DEBUG=1` or `DEBUG=1`.
fn debug_enabled_from(get: impl Fn(&str) -> Option<String>) -> bool {
    get("SEGKIT_DEBUG").as_deref() == Some("1") || get("DEBUG").as_deref() == Some("1")
}

fn debug_enabled() -> bool {
    debug_enabled_from(|k| std::env::var(k).ok())
}

/// Append a plain (uncolored) line to `${REPORTS_DIR:-reports}/segkit.log`.
/// Best-effort: logging must never abort the program, so failures are swallowed.
fn append_to_file(plain: &str) {
    let dir = std::env::var("REPORTS_DIR").unwrap_or_else(|_| "reports".into());
    if std::fs::create_dir_all(&dir).is_err() {
        return;
    }
    let path = format!("{dir}/segkit.log");
    if let Ok(mut f) = OpenOptions::new().create(true).append(true).open(&path) {
        let _ = writeln!(f, "{plain}");
    }
}

fn emit(level: Level, msg: &str) {
    let plain = plain_line(level, msg);
    append_to_file(&plain);

    let mut out = std::io::stderr();
    if out.is_terminal() && std::env::var_os("NO_COLOR").is_none() {
        let _ = writeln!(out, "{}", colored_line(level, msg));
    } else {
        let _ = writeln!(out, "{plain}");
    }
}

pub fn debug(msg: &str) {
    if debug_enabled() {
        emit(Level::Debug, msg);
    }
}

pub fn info(msg: &str) {
    emit(Level::Info, msg);
}

pub fn warn(msg: &str) {
    emit(Level::Warn, msg);
}

pub fn err(msg: &str) {
    emit(Level::Error, msg);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plain_line_matches_shell_prefix_format() {
        assert_eq!(plain_line(Level::Info, "hello"), "[INFO] [segkit] hello");
        assert_eq!(
            plain_line(Level::Warn, "careful"),
            "[WARN] [segkit] careful"
        );
        assert_eq!(plain_line(Level::Error, "boom"), "[ERROR] [segkit] boom");
        assert_eq!(plain_line(Level::Debug, "trace"), "[DEBUG] [segkit] trace");
    }

    #[test]
    fn plain_line_has_no_ansi_codes() {
        // The file sink must never receive color codes.
        let line = plain_line(Level::Error, "no color here");
        assert!(
            !line.contains('\x1b'),
            "plain line leaked an ANSI escape: {line:?}"
        );
    }

    #[test]
    fn colored_line_wraps_only_the_tag() {
        let line = colored_line(Level::Info, "msg");
        // Colored tag, then a reset, then the uncolored remainder.
        assert_eq!(line, "\x1b[1;34m[INFO]\x1b[0m [segkit] msg");
        assert!(line.starts_with(Level::Info.color()));
        assert!(line.contains(RESET));
        // Message text itself is not colored.
        assert!(line.ends_with("[segkit] msg"));
    }

    #[test]
    fn each_level_has_a_distinct_color_and_label() {
        let levels = [Level::Debug, Level::Info, Level::Warn, Level::Error];
        let labels: Vec<_> = levels.iter().map(|l| l.label()).collect();
        assert_eq!(labels, ["DEBUG", "INFO", "WARN", "ERROR"]);
        let colors: std::collections::BTreeSet<_> = levels.iter().map(|l| l.color()).collect();
        assert_eq!(colors.len(), 4, "level colors must be distinct");
    }

    #[test]
    fn debug_enabled_when_segkit_debug_is_one() {
        let env = |k: &str| (k == "SEGKIT_DEBUG").then(|| "1".to_string());
        assert!(debug_enabled_from(env));
    }

    #[test]
    fn debug_enabled_when_global_debug_is_one() {
        let env = |k: &str| (k == "DEBUG").then(|| "1".to_string());
        assert!(debug_enabled_from(env));
    }

    #[test]
    fn debug_disabled_when_unset() {
        let env = |_: &str| None;
        assert!(!debug_enabled_from(env));
    }

    #[test]
    fn debug_disabled_when_not_exactly_one() {
        let env = |k: &str| match k {
            "SEGKIT_DEBUG" => Some("0".to_string()),
            "DEBUG" => Some("true".to_string()),
            _ => None,
        };
        assert!(!debug_enabled_from(env));
    }
}
