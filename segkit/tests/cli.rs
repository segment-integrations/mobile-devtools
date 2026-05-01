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
        .stdout(predicate::str::contains("Segment SDK developer toolkit"));
}

#[test]
fn version_flag() {
    segkit()
        .arg("--version")
        .assert()
        .success()
        .stdout(predicate::str::contains("segkit"));
}
