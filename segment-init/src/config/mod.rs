pub mod devbox;
pub mod plugins;

use crate::error::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DevboxConfig {
    #[serde(default)]
    pub include: Vec<String>,

    #[serde(default)]
    pub packages: HashMap<String, String>,

    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub env: HashMap<String, String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub shell: Option<ShellConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShellConfig {
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub scripts: HashMap<String, Vec<String>>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deserialize_devbox_config() {
        let json = r#"{
            "include": ["path:../../plugins/android/plugin.json"],
            "packages": {
                "nodejs": "20",
                "jdk": "17"
            },
            "env": {
                "ANDROID_SDK_ROOT": "/path/to/sdk"
            }
        }"#;

        let config: DevboxConfig = serde_json::from_str(json).unwrap();
        assert_eq!(config.include.len(), 1);
        assert_eq!(config.packages.len(), 2);
        assert_eq!(config.env.len(), 1);
    }

    #[test]
    fn test_serialize_devbox_config() {
        let mut config = DevboxConfig {
            include: vec!["github:repo?dir=plugins/android&ref=main".to_string()],
            packages: HashMap::new(),
            env: HashMap::new(),
            shell: None,
        };

        config.packages.insert("nodejs".to_string(), "20".to_string());

        let json = serde_json::to_string_pretty(&config).unwrap();
        assert!(json.contains("github:repo"));
        assert!(json.contains("nodejs"));
    }
}
