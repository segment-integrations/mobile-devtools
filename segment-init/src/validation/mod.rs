use crate::error::Result;
use std::path::Path;

#[derive(Debug, Default)]
pub struct ValidationReport {
    pub errors: Vec<String>,
    pub warnings: Vec<String>,
}

impl ValidationReport {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_error(&mut self, error: String) {
        self.errors.push(error);
    }

    pub fn add_warning(&mut self, warning: String) {
        self.warnings.push(warning);
    }

    pub fn is_valid(&self) -> bool {
        self.errors.is_empty()
    }

    pub fn print(&self) {
        if !self.errors.is_empty() {
            println!("Errors:");
            for error in &self.errors {
                println!("  ❌ {}", error);
            }
        }

        if !self.warnings.is_empty() {
            println!("Warnings:");
            for warning in &self.warnings {
                println!("  ⚠️  {}", warning);
            }
        }

        if self.is_valid() && self.warnings.is_empty() {
            println!("✓ Validation passed");
        }
    }
}

/// Validate a generated project
pub fn validate_project(project_dir: &Path) -> Result<ValidationReport> {
    let mut report = ValidationReport::new();

    // Check required files exist
    if !project_dir.join("devbox.json").exists() {
        report.add_error("devbox.json not found".to_string());
    }

    // TODO: Add more validation checks
    // - Verify devbox.json is valid JSON
    // - Check plugin URLs are rewritten
    // - Platform-specific validation

    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_validate_project_missing_devbox() {
        let temp_dir = TempDir::new().unwrap();
        let report = validate_project(temp_dir.path()).unwrap();

        assert!(!report.is_valid());
        assert_eq!(report.errors.len(), 1);
    }

    #[test]
    fn test_validate_project_with_devbox() {
        let temp_dir = TempDir::new().unwrap();
        fs::write(temp_dir.path().join("devbox.json"), "{}").unwrap();

        let report = validate_project(temp_dir.path()).unwrap();
        assert!(report.is_valid());
    }
}
