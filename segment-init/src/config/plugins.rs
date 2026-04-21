use crate::config::DevboxConfig;
use crate::error::Result;
use std::path::{Component, Path};

const DEFAULT_REPO: &str = "segment-integrations/mobile-devtools";

/// Rewrite plugin URLs from relative paths to GitHub URLs
pub fn rewrite_plugin_urls(
    devbox_json: &mut DevboxConfig,
    repo: &str,
    ref_name: &str,
) -> Result<()> {
    for include in &mut devbox_json.include {
        if let Some(path) = include.strip_prefix("path:") {
            let plugin_dir = extract_plugin_dir(path)?;

            *include = format!("github:{}?dir={}&ref={}", repo, plugin_dir, ref_name);
        }
    }
    Ok(())
}

/// Extract plugin directory from a relative path
/// e.g., "path:../../plugins/android/plugin.json" -> "plugins/android"
fn extract_plugin_dir(path: &str) -> Result<String> {
    let path = Path::new(path);
    let components: Vec<_> = path
        .components()
        .filter(|c| !matches!(c, Component::ParentDir | Component::CurDir))
        .collect();

    if components.is_empty() {
        return Err(crate::error::SegmentInitError::PluginRewrite(
            "Empty plugin path".to_string(),
        ));
    }

    // Take all but last (plugin.json)
    let dir = components[..components.len() - 1]
        .iter()
        .map(|c| c.as_os_str().to_string_lossy())
        .collect::<Vec<_>>()
        .join("/");

    if dir.is_empty() {
        return Err(crate::error::SegmentInitError::PluginRewrite(
            "Invalid plugin path".to_string(),
        ));
    }

    Ok(dir)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    #[test]
    fn test_extract_plugin_dir() {
        assert_eq!(
            extract_plugin_dir("../../plugins/android/plugin.json").unwrap(),
            "plugins/android"
        );
        assert_eq!(
            extract_plugin_dir("../../../plugins/ios/plugin.json").unwrap(),
            "plugins/ios"
        );
        assert_eq!(
            extract_plugin_dir("./plugins/react-native/plugin.json").unwrap(),
            "plugins/react-native"
        );
    }

    #[test]
    fn test_rewrite_plugin_urls() {
        let mut config = DevboxConfig {
            include: vec![
                "path:../../plugins/android/plugin.json".to_string(),
                "path:../../plugins/ios/plugin.json".to_string(),
            ],
            packages: HashMap::new(),
            env: HashMap::new(),
            shell: None,
        };

        rewrite_plugin_urls(&mut config, DEFAULT_REPO, "v0.1.0").unwrap();

        assert_eq!(config.include.len(), 2);
        assert_eq!(
            config.include[0],
            "github:segment-integrations/mobile-devtools?dir=plugins/android&ref=v0.1.0"
        );
        assert_eq!(
            config.include[1],
            "github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=v0.1.0"
        );
    }

    #[test]
    fn test_rewrite_skips_non_path_includes() {
        let mut config = DevboxConfig {
            include: vec![
                "path:../../plugins/android/plugin.json".to_string(),
                "github:some/repo?dir=plugins/other".to_string(),
            ],
            packages: HashMap::new(),
            env: HashMap::new(),
            shell: None,
        };

        rewrite_plugin_urls(&mut config, DEFAULT_REPO, "main").unwrap();

        assert_eq!(config.include.len(), 2);
        assert!(config.include[0].starts_with("github:"));
        assert_eq!(config.include[1], "github:some/repo?dir=plugins/other");
    }
}
