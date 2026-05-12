use std::io::{self, BufRead, IsTerminal, Write};
use std::path::PathBuf;
use std::process::{Command, ExitCode};

use crate::state;
use crate::util::brew::find_brew;
use crate::util::log::{err, info, warn};

// ============================================================================
// Core uninstall steps (always run)
// ============================================================================

/// Remove segkit from the user's nix profile.
fn remove_segkit() -> bool {
    if !state::breadcrumb_exists("installed-segkit") {
        // Try anyway in case segkit was installed manually
        info("Removing segkit from nix profile...");
    } else {
        info("Removing segkit from nix profile...");
    }

    let status = Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "profile",
            "remove",
            "--regex",
            "segkit",
        ])
        .status();

    match status {
        Ok(s) if s.success() => {
            state::remove_breadcrumb("installed-segkit");
            info("segkit removed.");
            true
        }
        Ok(_) => {
            // nix profile remove returns non-zero if the package isn't installed
            warn("segkit may already be removed from nix profile.");
            state::remove_breadcrumb("installed-segkit");
            true
        }
        Err(e) => {
            err(&format!("failed to run nix profile remove: {e}"));
            false
        }
    }
}

/// Remove Determinate Nix if it was installed by install.sh.
fn remove_nix() -> bool {
    if !state::breadcrumb_exists("installed-nix") {
        info("Nix was not installed by segkit, skipping.");
        return true;
    }

    let nix_installer = PathBuf::from("/nix/nix-installer");
    if !nix_installer.exists() {
        warn("Determinate Nix installer not found at /nix/nix-installer. May already be removed.");
        state::remove_breadcrumb("installed-nix");
        return true;
    }

    info("Removing Determinate Nix (installed by segkit)...");
    let status = Command::new(&nix_installer)
        .args(["uninstall", "--no-confirm"])
        .status();

    match status {
        Ok(s) if s.success() => {
            state::remove_breadcrumb("installed-nix");
            info("Determinate Nix removed.");
            true
        }
        Ok(s) => {
            err(&format!(
                "nix-installer uninstall exited with code {}",
                s.code().unwrap_or(-1)
            ));
            false
        }
        Err(e) => {
            err(&format!("failed to run nix-installer uninstall: {e}"));
            false
        }
    }
}

// ============================================================================
// Doctor-installed dependency removal (--all)
// ============================================================================

struct DoctorDep {
    name: &'static str,
    breadcrumb: &'static str,
}

const DOCTOR_DEPS: &[DoctorDep] = &[
    DoctorDep {
        name: "applesimutils",
        breadcrumb: "installed-applesimutils",
    },
    DoctorDep {
        name: "homebrew",
        breadcrumb: "installed-homebrew",
    },
    DoctorDep {
        name: "devbox",
        breadcrumb: "installed-devbox",
    },
];

fn remove_applesimutils() -> bool {
    if !state::breadcrumb_exists("installed-applesimutils") {
        return true;
    }

    info("Removing applesimutils (installed by segkit doctor)...");
    let brew = find_brew();
    let status = Command::new(&brew)
        .args(["uninstall", "applesimutils"])
        .status();

    match status {
        Ok(s) if s.success() => {
            state::remove_breadcrumb("installed-applesimutils");
            info("applesimutils removed.");
            true
        }
        Ok(_) => {
            warn("brew uninstall applesimutils may have already been removed.");
            state::remove_breadcrumb("installed-applesimutils");
            true
        }
        Err(e) => {
            err(&format!("failed to run brew uninstall: {e}"));
            false
        }
    }
}

fn remove_devbox() -> bool {
    if !state::breadcrumb_exists("installed-devbox") {
        return true;
    }

    // devbox is typically installed to ~/.local/bin/devbox
    let devbox_path = which::which("devbox");

    match devbox_path {
        Ok(path) => {
            info(&format!("Removing devbox at {}...", path.display()));
            match std::fs::remove_file(&path) {
                Ok(()) => {
                    state::remove_breadcrumb("installed-devbox");
                    info("devbox removed.");
                    true
                }
                Err(e) => {
                    err(&format!("failed to remove {}: {e}", path.display()));
                    false
                }
            }
        }
        Err(_) => {
            warn("devbox not found in PATH. May already be removed.");
            state::remove_breadcrumb("installed-devbox");
            true
        }
    }
}

fn remove_homebrew() -> bool {
    if !state::breadcrumb_exists("installed-homebrew") {
        return true;
    }

    info("Removing Homebrew (installed by segkit doctor)...");
    let status = Command::new("bash")
        .args([
            "-c",
            "NONINTERACTIVE=1 /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\"",
        ])
        .status();

    match status {
        Ok(s) if s.success() => {
            state::remove_breadcrumb("installed-homebrew");
            info("Homebrew removed.");
            true
        }
        Ok(s) => {
            err(&format!(
                "Homebrew uninstaller exited with code {}",
                s.code().unwrap_or(-1)
            ));
            false
        }
        Err(e) => {
            err(&format!("failed to run Homebrew uninstaller: {e}"));
            false
        }
    }
}

fn remove_doctor_dep(name: &str) -> bool {
    match name {
        "applesimutils" => remove_applesimutils(),
        "devbox" => remove_devbox(),
        "homebrew" => remove_homebrew(),
        _ => {
            warn(&format!("unknown dependency: {name}"));
            true
        }
    }
}

/// Prompt the user to select which doctor-installed deps to remove.
/// Returns the list of dep names to remove.
fn prompt_selection(installed: &[&DoctorDep]) -> Vec<String> {
    eprintln!("\nThe following were installed by 'segkit doctor --fix':\n");
    for (i, dep) in installed.iter().enumerate() {
        eprintln!("  [{}] {}", i + 1, dep.name);
    }
    eprintln!();
    eprint!("Enter numbers to remove (e.g. 1,3), 'all' to remove all, or 'none' to skip: ");
    let _ = io::stderr().flush();

    let mut input = String::new();
    if io::stdin().lock().read_line(&mut input).is_err() {
        return Vec::new();
    }
    let input = input.trim();

    if input.eq_ignore_ascii_case("none") || input.is_empty() {
        return Vec::new();
    }
    if input.eq_ignore_ascii_case("all") {
        return installed.iter().map(|d| d.name.to_string()).collect();
    }

    let mut selected = Vec::new();
    for part in input.split([',', ' ']) {
        let part = part.trim();
        if let Ok(n) = part.parse::<usize>() {
            if n >= 1 && n <= installed.len() {
                selected.push(installed[n - 1].name.to_string());
            }
        }
    }
    selected
}

// ============================================================================
// Public entry point
// ============================================================================

pub fn run(all: bool, keep: &[String]) -> ExitCode {
    let mut ok = true;

    // 1. Remove segkit from nix profile (before removing nix)
    if !remove_segkit() {
        ok = false;
    }

    // 2. Handle doctor-installed dependencies if --all
    if all {
        let installed: Vec<&DoctorDep> = DOCTOR_DEPS
            .iter()
            .filter(|d| state::breadcrumb_exists(d.breadcrumb))
            .collect();

        if installed.is_empty() {
            info("No doctor-installed dependencies to remove.");
        } else {
            let to_remove: Vec<String> = if keep.is_empty() && io::stdin().is_terminal() {
                prompt_selection(&installed)
            } else {
                // Non-interactive or --keep provided: remove all except kept
                installed
                    .iter()
                    .filter(|d| !keep.iter().any(|k| k.eq_ignore_ascii_case(d.name)))
                    .map(|d| d.name.to_string())
                    .collect()
            };

            for name in &to_remove {
                if keep.iter().any(|k| k.eq_ignore_ascii_case(name)) {
                    info(&format!("Keeping {name} (--keep)."));
                    continue;
                }
                if !remove_doctor_dep(name) {
                    ok = false;
                }
            }
        }
    }

    // 3. Remove Determinate Nix if we installed it
    if !remove_nix() {
        ok = false;
    }

    // 4. Clean up state directory (only if no breadcrumbs remain)
    let dir = state::state_dir();
    if dir.exists() {
        let remaining: Vec<_> = std::fs::read_dir(&dir)
            .map(|entries| entries.filter_map(|e| e.ok()).collect())
            .unwrap_or_default();
        if remaining.is_empty() {
            let _ = std::fs::remove_dir_all(&dir);
        }
    }

    if ok {
        info("Uninstall complete.");
        ExitCode::SUCCESS
    } else {
        err("Uninstall completed with errors. See messages above.");
        ExitCode::FAILURE
    }
}
