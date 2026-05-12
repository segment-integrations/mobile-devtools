use std::fs;
use std::path::PathBuf;

/// Search for a file by name in the current directory and its immediate subdirectories.
/// Returns the first match found.
pub fn find_file(filename: &str) -> Option<PathBuf> {
    let cwd = std::env::current_dir().ok()?;

    // Check immediate subdirectories (e.g. <Name>/filename)
    let entries = fs::read_dir(&cwd).ok()?;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            let candidate = path.join(filename);
            if candidate.exists() {
                return Some(candidate);
            }
        }
    }

    // Also check cwd itself
    let candidate = cwd.join(filename);
    if candidate.exists() {
        return Some(candidate);
    }

    None
}
