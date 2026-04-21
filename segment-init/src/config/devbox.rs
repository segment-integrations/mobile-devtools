use crate::config::DevboxConfig;
use crate::error::Result;
use std::fs;
use std::path::Path;

/// Read and parse devbox.json from a file
pub fn read_devbox_json(path: &Path) -> Result<DevboxConfig> {
    let contents = fs::read_to_string(path)?;
    let config: DevboxConfig = serde_json::from_str(&contents)?;
    Ok(config)
}

/// Write devbox config to a file with pretty formatting
pub fn write_devbox_json(path: &Path, config: &DevboxConfig) -> Result<()> {
    let json = serde_json::to_string_pretty(config)?;
    fs::write(path, json)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use tempfile::TempDir;

    #[test]
    fn test_read_write_devbox_json() {
        let temp_dir = TempDir::new().unwrap();
        let devbox_path = temp_dir.path().join("devbox.json");

        let mut config = DevboxConfig {
            include: vec!["github:repo?dir=plugins/android&ref=main".to_string()],
            packages: HashMap::new(),
            env: HashMap::new(),
            shell: None,
        };

        config
            .packages
            .insert("nodejs".to_string(), "20".to_string());

        write_devbox_json(&devbox_path, &config).unwrap();

        let read_config = read_devbox_json(&devbox_path).unwrap();
        assert_eq!(read_config.include, config.include);
        assert_eq!(read_config.packages, config.packages);
    }
}
