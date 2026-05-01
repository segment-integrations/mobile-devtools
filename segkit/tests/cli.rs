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
        .stdout(predicate::str::contains("metro"))
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
        .env_remove("REACT_NATIVE_SCRIPTS_DIR")
        .env("PATH", "")
        .assert()
        .failure()
        .stderr(predicate::str::contains("rn.sh not found"));
}

#[test]
fn metro_subcommand_without_script_fails_gracefully() {
    segkit()
        .args(["metro", "start", "ios"])
        .env_remove("REACT_NATIVE_SCRIPTS_DIR")
        .env("PATH", "")
        .assert()
        .failure()
        .stderr(predicate::str::contains("metro.sh not found"));
}

#[test]
fn setup_detects_devbox() {
    segkit()
        .arg("setup")
        .assert()
        .stdout(predicate::str::contains("devbox:"));
}
