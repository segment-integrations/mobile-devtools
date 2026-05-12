use std::path::Path;

use super::platform::is_macos;

/// Return the Homebrew bin directory if brew is installed, or None.
pub fn homebrew_bin_dir() -> Option<&'static str> {
    if !is_macos() {
        return None;
    }
    if Path::new("/opt/homebrew/bin/brew").exists() {
        Some("/opt/homebrew/bin")
    } else if Path::new("/usr/local/bin/brew").exists() {
        Some("/usr/local/bin")
    } else {
        None
    }
}

/// Return the full path to the brew binary, falling back to bare "brew".
pub fn find_brew() -> String {
    homebrew_bin_dir()
        .map(|d| format!("{d}/brew"))
        .unwrap_or_else(|| "brew".into())
}

/// Ensure the Homebrew bin directory is on PATH for the current process.
pub fn ensure_homebrew_in_path() {
    if let Some(brew_dir) = homebrew_bin_dir() {
        let path = std::env::var("PATH").unwrap_or_default();
        if !path.split(':').any(|p| p == brew_dir) {
            // SAFETY: segkit is single-threaded at this point
            unsafe {
                std::env::set_var("PATH", format!("{brew_dir}:{path}"));
            }
        }
    }
}
