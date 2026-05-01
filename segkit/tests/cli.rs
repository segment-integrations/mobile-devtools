use assert_cmd::Command;
use predicates::prelude::*;

fn segkit() -> Command {
    Command::cargo_bin("segkit").unwrap()
}

#[test]
fn no_args_shows_help() {
    segkit()
        .assert()
        .failure()
        .stderr(predicate::str::contains("Usage"));
}

#[test]
fn help_flag() {
    segkit()
        .arg("--help")
        .assert()
        .success()
        .stdout(predicate::str::contains("Segment SDK developer toolkit"));
}

#[test]
fn init_help() {
    segkit()
        .args(["init", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("--sdk"))
        .stdout(predicate::str::contains("--name"))
        .stdout(predicate::str::contains("--issue"));
}

#[test]
fn repro_help() {
    segkit()
        .args(["repro", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("package"))
        .stdout(predicate::str::contains("share"));
}

#[test]
fn init_requires_sdk() {
    segkit()
        .args(["init", "--name", "test"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("--sdk"));
}

#[test]
fn init_requires_name_or_issue() {
    segkit()
        .args(["init", "--sdk", "swift"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("--name or --issue"));
}

#[test]
fn init_invalid_sdk() {
    segkit()
        .args(["init", "--sdk", "java", "--name", "test"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unknown SDK"));
}

#[test]
fn init_accepts_rn_shorthand() {
    segkit()
        .args(["init", "--sdk", "rn", "--name", "test"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("not yet implemented"));
}

#[test]
fn repro_share_requires_issue() {
    segkit()
        .args(["repro", "share"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("--issue"));
}
