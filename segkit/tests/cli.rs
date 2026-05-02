use assert_cmd::Command;
use predicates::prelude::*;

fn segkit() -> Command {
    Command::cargo_bin("segkit").unwrap()
}

#[test]
fn no_args_prints_version() {
    segkit()
        .assert()
        .success()
        .stdout(predicate::str::contains("segkit 0.1.0"));
}

#[test]
fn help_flag() {
    segkit()
        .arg("--help")
        .assert()
        .success()
        .stdout(predicate::str::contains("Segment SDK developer toolkit"))
        .stdout(predicate::str::contains("android"))
        .stdout(predicate::str::contains("ios"))
        .stdout(predicate::str::contains("rn"))
        .stdout(predicate::str::contains("setup"));
}

#[test]
fn version_flag() {
    segkit()
        .arg("--version")
        .assert()
        .success()
        .stdout(predicate::str::contains("segkit"));
}

#[test]
fn android_subcommand_without_script_fails_gracefully() {
    segkit()
        .args(["android", "devices", "list"])
        .env_remove("ANDROID_SCRIPTS_DIR")
        .env("PATH", "")
        .assert()
        .failure()
        .stderr(predicate::str::contains("android.sh not found"));
}

#[test]
fn ios_subcommand_without_script_fails_gracefully() {
    segkit()
        .args(["ios", "devices", "list"])
        .env_remove("IOS_SCRIPTS_DIR")
        .env("PATH", "")
        .assert()
        .failure()
        .stderr(predicate::str::contains("ios.sh not found"));
}

#[test]
fn rn_subcommand_without_script_fails_gracefully() {
    segkit()
        .args(["rn", "doctor"])
        .env_remove("RN_SCRIPTS_DIR")
        .env("PATH", "")
        .assert()
        .failure()
        .stderr(predicate::str::contains("rn.sh not found"));
}

#[test]
fn setup_detects_devbox() {
    segkit()
        .arg("setup")
        .assert()
        .stdout(predicate::str::contains("devbox:"));
}

#[test]
fn ci_wrap_runs_command_and_writes_timing() {
    let dir = tempfile::tempdir().unwrap();
    segkit()
        .args(["ci", "wrap", "--", "echo", "hello"])
        .env("REPORTS_DIR", dir.path())
        .assert()
        .success()
        .stdout(predicate::str::contains("hello"));

    let timing = std::fs::read_to_string(dir.path().join("segkit-timing.jsonl")).unwrap();
    assert!(timing.contains("echo hello"));
    assert!(timing.contains("\"exit_code\":0"));
}

#[test]
fn ci_wrap_captures_nonzero_exit() {
    let dir = tempfile::tempdir().unwrap();
    segkit()
        .args(["ci", "wrap", "--", "sh", "-c", "exit 42"])
        .env("REPORTS_DIR", dir.path())
        .assert()
        .code(42);

    let timing = std::fs::read_to_string(dir.path().join("segkit-timing.jsonl")).unwrap();
    assert!(timing.contains("\"exit_code\":42"));

    let errors = std::fs::read_to_string(dir.path().join("segkit-errors.jsonl")).unwrap();
    assert!(errors.contains("\"exit_code\":42"));
}

#[test]
fn ci_wrap_no_command_fails() {
    segkit()
        .args(["ci", "wrap"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("no command specified"));
}

#[test]
fn ci_summary_with_timing_data() {
    let dir = tempfile::tempdir().unwrap();
    let timing_path = dir.path().join("segkit-timing.jsonl");
    std::fs::write(
        &timing_path,
        r#"{"ts":"2026-01-01T00:00:00Z","command":"build app","duration_ms":5000,"exit_code":0,"stderr_tail":""}
{"ts":"2026-01-01T00:01:00Z","command":"deploy app","duration_ms":3200,"exit_code":0,"stderr_tail":""}
"#,
    )
    .unwrap();

    segkit()
        .args(["ci", "summary", "--platform", "android", "--device", "max"])
        .env("REPORTS_DIR", dir.path())
        .assert()
        .success()
        .stdout(predicate::str::contains("android — max"))
        .stdout(predicate::str::contains("build app"))
        .stdout(predicate::str::contains("5.0s"))
        .stdout(predicate::str::contains("deploy app"))
        .stdout(predicate::str::contains("Total"));
}

#[test]
fn ci_summary_no_data_fails() {
    let dir = tempfile::tempdir().unwrap();
    segkit()
        .args(["ci", "summary"])
        .env("REPORTS_DIR", dir.path())
        .assert()
        .failure()
        .stderr(predicate::str::contains("no timing data found"));
}

#[test]
fn ci_summary_shows_errors() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::write(
        dir.path().join("segkit-timing.jsonl"),
        r#"{"ts":"2026-01-01T00:00:00Z","command":"build","duration_ms":1000,"exit_code":1,"stderr_tail":""}
"#,
    )
    .unwrap();
    std::fs::write(
        dir.path().join("segkit-errors.jsonl"),
        r#"{"ts":"2026-01-01T00:00:00Z","command":"build","exit_code":1,"stderr_tail":"build failed"}
"#,
    )
    .unwrap();

    segkit()
        .args(["ci", "summary"])
        .env("REPORTS_DIR", dir.path())
        .assert()
        .code(1)
        .stdout(predicate::str::contains("FAIL (exit 1)"))
        .stdout(predicate::str::contains("build failed"));
}
