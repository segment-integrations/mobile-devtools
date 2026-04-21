use crate::cli::{Platform, ProjectConfig};
use crate::error::{Result, SegmentInitError};

/// Build project config from command-line flags
pub fn build_config_from_flags(
    path: Option<String>,
    name: Option<String>,
    platform: Option<String>,
    package_id: Option<String>,
    bundle_id: Option<String>,
    plugin_ref: String,
    git_init: bool,
) -> Result<ProjectConfig> {
    // Validate required fields
    let name = name.ok_or_else(|| SegmentInitError::MissingField("name".to_string()))?;

    let platform =
        platform.ok_or_else(|| SegmentInitError::MissingField("platform".to_string()))?;

    // Parse platforms
    let platforms: Result<Vec<Platform>> = platform
        .split(',')
        .map(|s| Platform::from_str(s.trim()))
        .collect();
    let platforms = platforms?;

    // Default output path if not provided
    let output_path = path.unwrap_or_else(|| format!("./{}", to_kebab_case(&name)));

    Ok(ProjectConfig {
        name,
        output_path,
        platforms,
        package_id,
        bundle_id,
        plugin_ref,
        git_init,
    })
}

fn to_kebab_case(s: &str) -> String {
    s.to_lowercase().replace(' ', "-")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_build_config_from_flags() {
        let config = build_config_from_flags(
            Some("./my-app".to_string()),
            Some("My App".to_string()),
            Some("android,ios".to_string()),
            Some("com.example.app".to_string()),
            Some("com.example.app".to_string()),
            "main".to_string(),
            true,
        )
        .unwrap();

        assert_eq!(config.name, "My App");
        assert_eq!(config.output_path, "./my-app");
        assert_eq!(config.platforms.len(), 2);
        assert!(config.platforms.contains(&Platform::Android));
        assert!(config.platforms.contains(&Platform::Ios));
        assert_eq!(config.package_id, Some("com.example.app".to_string()));
        assert_eq!(config.bundle_id, Some("com.example.app".to_string()));
        assert_eq!(config.plugin_ref, "main");
        assert!(config.git_init);
    }

    #[test]
    fn test_missing_name_fails() {
        let result = build_config_from_flags(
            None,
            None,
            Some("android".to_string()),
            None,
            None,
            "main".to_string(),
            false,
        );

        assert!(result.is_err());
    }

    #[test]
    fn test_invalid_platform_fails() {
        let result = build_config_from_flags(
            None,
            Some("App".to_string()),
            Some("invalid".to_string()),
            None,
            None,
            "main".to_string(),
            false,
        );

        assert!(result.is_err());
    }
}
