use crate::cli::Platform;
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct Template {
    pub platform: Platform,
    pub source_path: PathBuf,
}

/// Patterns for files that should be excluded when copying templates
pub const EXCLUDE_PATTERNS: &[&str] = &[
    ".devbox/",
    "devbox.d/",
    "node_modules/",
    "build/",
    ".gradle/",
    "Pods/",
    "DerivedData/",
    "reports/",
    "tests/",
    ".git/",
    "devbox.lock",
];

/// Patterns for files that should be included (processed as templates)
pub const TEMPLATE_PATTERNS: &[&str] = &[
    "devbox.json",
    "**/*.gradle",
    "**/*.kts",
    "**/*.pbxproj",
    "**/*.swift",
    "**/*.kt",
    "**/*.java",
    "**/*.xml",
    "package.json",
    "app.json",
];
