use std::io::Write;
use std::process::{Command, ExitCode, Stdio};
use std::time::Instant;

use anyhow::{Context, Result};
use chrono::Utc;

fn reports_dir() -> String {
    std::env::var("REPORTS_DIR").unwrap_or_else(|_| "reports".into())
}

pub fn wrap(command: &[String]) -> ExitCode {
    if command.is_empty() {
        eprintln!("segkit ci wrap: no command specified");
        return ExitCode::from(1);
    }

    let label = command.join(" ");
    let start = Instant::now();

    let mut child = match Command::new(&command[0])
        .args(&command[1..])
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            eprintln!("segkit ci wrap: failed to execute '{}': {e}", command[0]);
            let duration_ms = start.elapsed().as_millis();
            write_timing(&label, duration_ms, 127, "");
            write_error(&label, 127, &e.to_string());
            return ExitCode::from(127);
        }
    };

    let stderr_handle = child.stderr.take();

    let stderr_output = std::thread::spawn(move || {
        use std::io::{BufRead, BufReader};
        let Some(stderr) = stderr_handle else {
            return String::new();
        };
        let reader = BufReader::new(stderr);
        let mut captured = String::new();
        for line in reader.lines() {
            match line {
                Ok(l) => {
                    eprintln!("{l}");
                    captured.push_str(&l);
                    captured.push('\n');
                }
                Err(_) => break,
            }
        }
        captured
    });

    let status = child.wait();
    let duration_ms = start.elapsed().as_millis();
    let stderr_text = stderr_output.join().unwrap_or_default();

    let stderr_tail: String = stderr_text
        .lines()
        .rev()
        .take(20)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect::<Vec<_>>()
        .join("\n");

    match status {
        Ok(s) => {
            let code = s.code().unwrap_or(1);
            write_timing(&label, duration_ms, code, &stderr_tail);
            if code != 0 {
                write_error(&label, code, &stderr_tail);
            }
            ExitCode::from(code as u8)
        }
        Err(e) => {
            eprintln!("segkit ci wrap: wait failed: {e}");
            write_timing(&label, duration_ms, 1, &stderr_tail);
            write_error(&label, 1, &format!("{e}\n{stderr_tail}"));
            ExitCode::from(1)
        }
    }
}

fn write_timing(label: &str, duration_ms: u128, exit_code: i32, stderr_tail: &str) {
    let dir = reports_dir();
    let _ = std::fs::create_dir_all(&dir);

    let entry = serde_json::json!({
        "ts": Utc::now().to_rfc3339(),
        "command": label,
        "duration_ms": duration_ms,
        "exit_code": exit_code,
        "stderr_tail": stderr_tail,
    });

    let path = format!("{dir}/segkit-timing.jsonl");
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
    {
        let _ = writeln!(f, "{}", entry);
    }
}

fn write_error(label: &str, exit_code: i32, stderr_tail: &str) {
    let dir = reports_dir();
    let _ = std::fs::create_dir_all(&dir);

    let entry = serde_json::json!({
        "ts": Utc::now().to_rfc3339(),
        "command": label,
        "exit_code": exit_code,
        "stderr_tail": stderr_tail,
    });

    let path = format!("{dir}/segkit-errors.jsonl");
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
    {
        let _ = writeln!(f, "{}", entry);
    }
}

#[derive(Debug)]
struct TimingEntry {
    command: String,
    duration_ms: u128,
    exit_code: i32,
}

fn read_timing_entries() -> Result<Vec<TimingEntry>> {
    let path = format!("{}/segkit-timing.jsonl", reports_dir());
    let content = std::fs::read_to_string(&path)
        .with_context(|| format!("no timing data found at {path}"))?;

    let mut entries = Vec::new();
    for line in content.lines() {
        if line.trim().is_empty() {
            continue;
        }
        if let Ok(v) = serde_json::from_str::<serde_json::Value>(line) {
            entries.push(TimingEntry {
                command: v["command"].as_str().unwrap_or("?").to_string(),
                duration_ms: v["duration_ms"].as_u64().unwrap_or(0) as u128,
                exit_code: v["exit_code"].as_i64().unwrap_or(-1) as i32,
            });
        }
    }
    Ok(entries)
}

#[derive(Debug)]
struct ErrorEntry {
    ts: String,
    command: String,
    exit_code: i32,
    stderr_tail: String,
}

fn read_error_entries() -> Vec<ErrorEntry> {
    let path = format!("{}/segkit-errors.jsonl", reports_dir());
    let content = match std::fs::read_to_string(&path) {
        Ok(c) => c,
        Err(_) => return Vec::new(),
    };

    let mut entries = Vec::new();
    for line in content.lines() {
        if line.trim().is_empty() {
            continue;
        }
        if let Ok(v) = serde_json::from_str::<serde_json::Value>(line) {
            entries.push(ErrorEntry {
                ts: v["ts"].as_str().unwrap_or("").to_string(),
                command: v["command"].as_str().unwrap_or("?").to_string(),
                exit_code: v["exit_code"].as_i64().unwrap_or(-1) as i32,
                stderr_tail: v["stderr_tail"].as_str().unwrap_or("").to_string(),
            });
        }
    }
    entries
}

pub fn summary(platform: Option<&str>, device: Option<&str>) -> ExitCode {
    let entries = match read_timing_entries() {
        Ok(e) if !e.is_empty() => e,
        Ok(_) => {
            eprintln!("segkit ci summary: no timing entries found");
            return ExitCode::from(1);
        }
        Err(e) => {
            eprintln!("segkit ci summary: {e:#}");
            return ExitCode::from(1);
        }
    };

    let errors = read_error_entries();

    let mut md = String::new();

    if let (Some(p), Some(d)) = (platform, device) {
        md.push_str(&format!("## {p} — {d}\n\n"));
    } else if let Some(p) = platform {
        md.push_str(&format!("## {p}\n\n"));
    } else {
        md.push_str("## CI Step Timing\n\n");
    }

    md.push_str("| Step | Duration | Status |\n");
    md.push_str("|------|----------|--------|\n");

    let mut total_ms: u128 = 0;
    let mut any_failed = false;

    for entry in &entries {
        let status = if entry.exit_code == 0 {
            "pass".to_string()
        } else {
            any_failed = true;
            format!("FAIL (exit {})", entry.exit_code)
        };
        let duration = format_duration(entry.duration_ms);
        md.push_str(&format!("| {} | {} | {} |\n", entry.command, duration, status));
        total_ms += entry.duration_ms;
    }

    md.push_str(&format!(
        "| **Total** | **{}** | {} |\n",
        format_duration(total_ms),
        if any_failed { "**FAIL**" } else { "pass" }
    ));

    if !errors.is_empty() {
        md.push_str("\n### Errors\n\n");
        for err in &errors {
            md.push_str(&format!(
                "<details><summary>{} (exit {}, {})</summary>\n\n```\n{}\n```\n\n</details>\n\n",
                err.command, err.exit_code, err.ts, err.stderr_tail
            ));
        }
    }

    print!("{md}");

    if let Ok(summary_path) = std::env::var("GITHUB_STEP_SUMMARY") {
        if let Ok(mut f) = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&summary_path)
        {
            let _ = write!(f, "{md}");
        }
    }

    if any_failed {
        ExitCode::from(1)
    } else {
        ExitCode::SUCCESS
    }
}

fn format_duration(ms: u128) -> String {
    if ms < 1_000 {
        format!("{ms}ms")
    } else if ms < 60_000 {
        format!("{:.1}s", ms as f64 / 1_000.0)
    } else {
        let mins = ms / 60_000;
        let secs = (ms % 60_000) / 1_000;
        format!("{mins}m{secs:02}s")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_duration_millis() {
        assert_eq!(format_duration(500), "500ms");
    }

    #[test]
    fn format_duration_seconds() {
        assert_eq!(format_duration(3_500), "3.5s");
    }

    #[test]
    fn format_duration_minutes() {
        assert_eq!(format_duration(125_000), "2m05s");
    }
}
