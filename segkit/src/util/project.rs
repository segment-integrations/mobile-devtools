use std::fs;
use std::path::PathBuf;

/// Scan current directory and immediate subdirectories for a SegmentConfig.xcconfig file.
pub fn find_segment_config() -> Option<PathBuf> {
    let cwd = std::env::current_dir().ok()?;

    // Check immediate subdirectories (e.g. <Name>/SegmentConfig.xcconfig)
    let entries = fs::read_dir(&cwd).ok()?;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            let candidate = path.join("SegmentConfig.xcconfig");
            if candidate.exists() {
                return Some(candidate);
            }
        }
    }

    // Also check cwd itself
    let candidate = cwd.join("SegmentConfig.xcconfig");
    if candidate.exists() {
        return Some(candidate);
    }

    None
}
