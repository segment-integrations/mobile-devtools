use std::process::{Command, ExitCode};

use crate::util::log::{err, info};

const FLAKE_REF: &str = "github:segment-integrations/mobile-devtools?dir=segkit#segkit";

pub fn run() -> ExitCode {
    info("Updating segkit to latest main...");

    // Remove current installation
    info("Removing current version...");
    let remove = Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "profile",
            "remove",
            "segkit",
        ])
        .status();

    match remove {
        Ok(s) if s.success() => {}
        _ => {
            // Not fatal — may not be installed via profile, or name may differ.
            // Try a regex match as fallback.
            let _ = Command::new("nix")
                .args([
                    "--extra-experimental-features",
                    "nix-command flakes",
                    "profile",
                    "remove",
                    "--regex",
                    ".*segkit.*",
                ])
                .status();
        }
    }

    // Install latest from main
    info("Installing latest version...");
    let install = Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "profile",
            "install",
            "--refresh",
            FLAKE_REF,
        ])
        .status();

    match install {
        Ok(s) if s.success() => {
            info("Updated! Run 'segkit --version' to verify.");
            ExitCode::SUCCESS
        }
        Ok(s) => {
            err(&format!(
                "nix profile install exited with code {}",
                s.code().unwrap_or(-1)
            ));
            ExitCode::FAILURE
        }
        Err(e) => {
            err(&format!("Failed to run nix: {e}"));
            ExitCode::FAILURE
        }
    }
}
