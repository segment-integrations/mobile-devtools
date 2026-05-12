use std::fs;
use std::path::Path;

use super::log::err;

/// Write a file relative to a base directory, creating parent directories as needed.
pub fn write_file(base: &Path, rel_path: &str, content: &str) {
    let path = base.join(rel_path);
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    fs::write(&path, content).unwrap_or_else(|e| {
        err(&format!("Failed to write {}: {e}", path.display()));
    });
}
