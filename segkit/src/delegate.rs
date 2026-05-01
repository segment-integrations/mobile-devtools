use std::io::Write;
use std::process::{Command, ExitCode};
use std::time::Instant;

use anyhow::{Context, Result};
use chrono::Utc;

fn reports_dir() -> String {
    std::env::var("REPORTS_DIR").unwrap_or_else(|_| "reports".into())
}

fn resolve_script(name: &str) -> Result<String> {
    anyhow::ensure!(
        !name.contains("..") && !name.contains('/') && !name.contains('\\'),
        "invalid script name: {name}"
    );

    let env_keys: &[&str] = if name.starts_with("android") {
        &["ANDROID_SCRIPTS_DIR"]
    } else if name.starts_with("ios") {
        &["IOS_SCRIPTS_DIR"]
    } else {
        &["REACT_NATIVE_SCRIPTS_DIR"]
    };

    for env_key in env_keys {
        if let Ok(scripts_dir) = std::env::var(env_key) {
            let path = format!("{}/user/{}", scripts_dir, name);
            if std::path::Path::new(&path).exists() {
                return Ok(path);
            }
        }
    }

    let primary_key = env_keys[0];
    which::which(name)
        .map(|p| p.to_string_lossy().into_owned())
        .with_context(|| format!("{name} not found in PATH or ${primary_key}"))
}

fn append_timing(script: &str, args: &[String], duration_ms: u128, exit_code: i32) {
    let dir = reports_dir();
    let _ = std::fs::create_dir_all(&dir);
    let path = format!("{}/segkit-timing.jsonl", dir);

    let entry = serde_json::json!({
        "ts": Utc::now().to_rfc3339(),
        "command": format!("{} {}", script, args.join(" ")),
        "duration_ms": duration_ms,
        "exit_code": exit_code,
    });

    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
    {
        let _ = writeln!(f, "{}", entry);
    }
}

fn append_error(script: &str, args: &[String], exit_code: i32, stderr_tail: &str) {
    let dir = reports_dir();
    let _ = std::fs::create_dir_all(&dir);
    let path = format!("{}/segkit-errors.jsonl", dir);

    let entry = serde_json::json!({
        "ts": Utc::now().to_rfc3339(),
        "command": format!("{} {}", script, args.join(" ")),
        "exit_code": exit_code,
        "stderr_tail": stderr_tail,
    });

    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
    {
        let _ = writeln!(f, "{}", entry);
    }
}

pub fn run(script: &str, args: &[String]) -> ExitCode {
    let script_path = match resolve_script(script) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("segkit: {e:#}");
            return ExitCode::from(127);
        }
    };

    let start = Instant::now();

    let status = Command::new(&script_path).args(args).status();

    let duration_ms = start.elapsed().as_millis();

    match status {
        Ok(s) => {
            let code = s.code().unwrap_or(1);
            append_timing(script, args, duration_ms, code);
            if code != 0 {
                append_error(script, args, code, "");
            }
            ExitCode::from(code as u8)
        }
        Err(e) => {
            eprintln!("segkit: failed to execute {script_path}: {e}");
            append_timing(script, args, duration_ms, 126);
            append_error(script, args, 126, &e.to_string());
            ExitCode::from(126)
        }
    }
}
