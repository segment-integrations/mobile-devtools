use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn test_cli_help() {
    let mut cmd = Command::cargo_bin("segment-init").unwrap();
    cmd.arg("--help");
    cmd.assert()
        .success()
        .stdout(predicate::str::contains("CLI tool for creating reproducible Segment mobile projects"));
}

#[test]
fn test_list_templates() {
    let mut cmd = Command::cargo_bin("segment-init").unwrap();
    cmd.arg("list-templates");
    cmd.assert()
        .success()
        .stdout(predicate::str::contains("android"))
        .stdout(predicate::str::contains("ios"))
        .stdout(predicate::str::contains("react-native"));
}

#[test]
fn test_list_sdks() {
    let mut cmd = Command::cargo_bin("segment-init").unwrap();
    cmd.arg("list-sdks");
    cmd.assert()
        .success()
        .stdout(predicate::str::contains("analytics-android"))
        .stdout(predicate::str::contains("analytics-ios"));
}

#[test]
fn test_create_without_flags_shows_not_implemented() {
    let mut cmd = Command::cargo_bin("segment-init").unwrap();
    cmd.arg("create").arg("test-app");
    cmd.assert()
        .success()
        .stdout(predicate::str::contains("not yet implemented"));
}
