use std::process::{Command, ExitCode};

const DEVBOX_INSTALL_URL: &str = "https://get.jetify.com/devbox";
const HOMEBREW_INSTALL_URL: &str =
    "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh";

fn is_installed(cmd: &str) -> bool {
    which::which(cmd).is_ok()
}

fn is_macos() -> bool {
    cfg!(target_os = "macos")
}

fn homebrew_bin_dir() -> Option<&'static str> {
    if !is_macos() {
        return None;
    }
    if std::path::Path::new("/opt/homebrew/bin/brew").exists() {
        Some("/opt/homebrew/bin")
    } else if std::path::Path::new("/usr/local/bin/brew").exists() {
        Some("/usr/local/bin")
    } else {
        None
    }
}

fn ensure_homebrew_in_path() {
    if let Some(brew_dir) = homebrew_bin_dir() {
        let path = std::env::var("PATH").unwrap_or_default();
        if !path.split(':').any(|p| p == brew_dir) {
            // SAFETY: segkit is single-threaded at this point
            unsafe {
                std::env::set_var("PATH", format!("{}:{}", brew_dir, path));
            }
        }
    }
}

// ============================================================================
// Installation functions
// ============================================================================

fn install_devbox() -> Result<(), String> {
    let status = if is_installed("curl") {
        Command::new("sh")
            .args(["-c", &format!("curl -fsSL {DEVBOX_INSTALL_URL} | bash")])
            .status()
    } else if is_installed("wget") {
        Command::new("sh")
            .args(["-c", &format!("wget -qO- {DEVBOX_INSTALL_URL} | bash")])
            .status()
    } else {
        return Err("neither curl nor wget found".into());
    };

    match status {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!("installer exited with code {}", s.code().unwrap_or(-1))),
        Err(e) => Err(format!("failed to run installer: {e}")),
    }
}

fn install_homebrew() -> Result<(), String> {
    let status = Command::new("bash")
        .args([
            "-c",
            &format!("NONINTERACTIVE=1 /bin/bash -c \"$(curl -fsSL {HOMEBREW_INSTALL_URL})\""),
        ])
        .status();

    match status {
        Ok(s) if s.success() => {
            ensure_homebrew_in_path();
            Ok(())
        }
        Ok(s) => Err(format!("installer exited with code {}", s.code().unwrap_or(-1))),
        Err(e) => Err(format!("failed to run installer: {e}")),
    }
}

fn install_applesimutils() -> Result<(), String> {
    ensure_homebrew_in_path();

    let brew = homebrew_bin_dir()
        .map(|d| format!("{}/brew", d))
        .unwrap_or_else(|| "brew".into());

    let status = Command::new(&brew).args(["tap", "wix/brew"]).status();
    match status {
        Ok(s) if !s.success() => {
            return Err(format!("brew tap wix/brew failed (code {})", s.code().unwrap_or(-1)));
        }
        Err(e) => return Err(format!("failed to run brew tap: {e}")),
        _ => {}
    }

    let status = Command::new(&brew)
        .args(["install", "applesimutils"])
        .status();

    match status {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!("brew install failed (code {})", s.code().unwrap_or(-1))),
        Err(e) => Err(format!("failed to run brew install: {e}")),
    }
}

// ============================================================================
// Check results
// ============================================================================

enum CheckStatus {
    Ok,
    Missing,
    Fixed,
    Failed(String),
}

struct CheckResult {
    name: &'static str,
    status: CheckStatus,
}

// ============================================================================
// Individual checks
// ============================================================================

fn check_devbox(fix: bool) -> CheckResult {
    let name = "devbox";
    if is_installed("devbox") {
        return CheckResult { name, status: CheckStatus::Ok };
    }
    if !fix {
        return CheckResult { name, status: CheckStatus::Missing };
    }
    match install_devbox() {
        Ok(()) if is_installed("devbox") => CheckResult { name, status: CheckStatus::Fixed },
        Ok(()) => CheckResult { name, status: CheckStatus::Fixed },
        Err(e) => CheckResult { name, status: CheckStatus::Failed(e) },
    }
}

fn check_homebrew(fix: bool) -> CheckResult {
    let name = "homebrew";
    if !is_macos() {
        return CheckResult { name, status: CheckStatus::Ok };
    }

    ensure_homebrew_in_path();
    if is_installed("brew") {
        return CheckResult { name, status: CheckStatus::Ok };
    }
    if !fix {
        return CheckResult { name, status: CheckStatus::Missing };
    }
    match install_homebrew() {
        Ok(()) => CheckResult { name, status: CheckStatus::Fixed },
        Err(e) => CheckResult { name, status: CheckStatus::Failed(e) },
    }
}

fn check_applesimutils(fix: bool) -> CheckResult {
    let name = "applesimutils";
    if !is_macos() {
        return CheckResult { name, status: CheckStatus::Ok };
    }

    ensure_homebrew_in_path();
    if is_installed("applesimutils") {
        return CheckResult { name, status: CheckStatus::Ok };
    }
    if !fix {
        return CheckResult { name, status: CheckStatus::Missing };
    }
    if homebrew_bin_dir().is_none() {
        return CheckResult {
            name,
            status: CheckStatus::Failed("Homebrew not available".into()),
        };
    }
    match install_applesimutils() {
        Ok(()) => {
            ensure_homebrew_in_path();
            CheckResult { name, status: CheckStatus::Fixed }
        }
        Err(e) => CheckResult { name, status: CheckStatus::Failed(e) },
    }
}

// ============================================================================
// Public entry point
// ============================================================================

pub fn run(fix: bool) -> ExitCode {
    if fix {
        println!("Checking and fixing dependencies...");
    } else {
        println!("Checking dependencies...");
    }

    let results = vec![
        check_devbox(fix),
        check_homebrew(fix),
        check_applesimutils(fix),
    ];

    let mut any_missing = false;
    let mut any_fixed = false;
    let mut any_failed = false;

    for r in &results {
        match &r.status {
            CheckStatus::Ok => println!("  \u{2713} {}", r.name),
            CheckStatus::Missing => {
                println!("  \u{2717} {} (not installed)", r.name);
                any_missing = true;
            }
            CheckStatus::Fixed => {
                println!("  \u{2713} {} (just installed)", r.name);
                any_fixed = true;
            }
            CheckStatus::Failed(e) => {
                println!("  \u{2717} {} — {}", r.name, e);
                any_failed = true;
            }
        }
    }

    if any_failed {
        eprintln!("\nSome dependencies could not be installed.");
        return ExitCode::FAILURE;
    }

    if any_missing {
        eprintln!("\nMissing dependencies detected. Run `segkit doctor --fix` to install them.");
        return ExitCode::FAILURE;
    }

    if any_fixed {
        println!("\nDependencies installed. Restart your shell and retry your command.");
        return ExitCode::from(2);
    }

    println!("\nAll dependencies OK.");
    ExitCode::SUCCESS
}
