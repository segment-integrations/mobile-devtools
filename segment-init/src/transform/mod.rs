pub mod android;
pub mod ios;
pub mod react_native;
pub mod rename;

use crate::cli::ProjectConfig;
use crate::error::Result;
use std::path::Path;

/// Apply all transformations to a project based on configuration
pub fn apply_transformations(project_dir: &Path, config: &ProjectConfig) -> Result<()> {
    // TODO: Implement transformations
    // - Rename project
    // - Update package IDs / bundle IDs
    // - Rewrite plugin URLs
    // - Update strings.xml, Info.plist, etc.

    Ok(())
}
