pub mod types;

use crate::cli::Platform;
use crate::error::Result;
use std::path::Path;

/// Load template for a specific platform from the examples directory
pub fn load_template(platform: &Platform, examples_dir: &Path) -> Result<types::Template> {
    let template_path = examples_dir.join(platform.as_str());

    if !template_path.exists() {
        return Err(crate::error::SegmentInitError::TemplateNotFound(
            platform.as_str().to_string(),
        ));
    }

    Ok(types::Template {
        platform: platform.clone(),
        source_path: template_path,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_load_template() {
        let temp_dir = TempDir::new().unwrap();
        let examples_dir = temp_dir.path();

        // Create android template directory
        fs::create_dir(examples_dir.join("android")).unwrap();

        let template = load_template(&Platform::Android, examples_dir).unwrap();
        assert_eq!(template.platform, Platform::Android);
        assert!(template.source_path.exists());
    }

    #[test]
    fn test_load_template_not_found() {
        let temp_dir = TempDir::new().unwrap();
        let result = load_template(&Platform::Android, temp_dir.path());
        assert!(result.is_err());
    }
}
