use std::collections::BTreeSet;
use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

use crate::init_cmd::{validate_plugin_names, PLUGIN_REGISTRY};
use crate::util::log::{err, info};
use crate::util::project::find_file;
use crate::util::xcconfig::XCConfig;

fn parse_plugin_csv(raw: &str) -> BTreeSet<String> {
    if raw.is_empty() {
        return BTreeSet::new();
    }
    raw.split(',')
        .map(|s| s.trim().to_lowercase().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

/// Locate and parse SegmentConfig.conf from the project directory.
fn load_config() -> Result<(PathBuf, XCConfig), ExitCode> {
    let path = find_file("SegmentConfig.conf").ok_or_else(|| {
        err("No SegmentConfig.conf found. Are you in a segkit project directory?");
        ExitCode::FAILURE
    })?;

    let content = fs::read_to_string(&path).map_err(|e| {
        err(&format!("Failed to read {}: {}", path.display(), e));
        ExitCode::FAILURE
    })?;

    Ok((path, XCConfig::parse(&content)))
}

/// Validate and apply plugin list mutations (replace, add, remove).
/// Returns the updated CSV string.
fn apply_plugin_changes(
    config: &XCConfig,
    plugins: &Option<Vec<String>>,
    add_plugins: &[String],
    remove_plugins: &[String],
) -> Result<String, String> {
    // Validate all provided plugin names
    if let Some(list) = plugins {
        validate_plugin_names(list)?;
    }
    validate_plugin_names(add_plugins)?;
    validate_plugin_names(remove_plugins)?;

    // Start from --plugins (replace) or current value
    let mut current = if let Some(list) = plugins {
        list.iter().map(|s| s.to_lowercase()).collect::<BTreeSet<String>>()
    } else {
        let raw = config.get("ENABLED_PLUGINS").unwrap_or_default();
        parse_plugin_csv(&raw)
    };

    for p in add_plugins {
        current.insert(p.to_lowercase());
    }
    for p in remove_plugins {
        current.remove(&p.to_lowercase());
    }

    Ok(current.into_iter().collect::<Vec<_>>().join(","))
}

pub fn run_show() -> ExitCode {
    let (config_path, config) = match load_config() {
        Ok(v) => v,
        Err(code) => return code,
    };

    let write_key = config.get("SEGMENT_WRITE_KEY").unwrap_or_default();
    let enabled = parse_plugin_csv(&config.get("ENABLED_PLUGINS").unwrap_or_default());

    eprintln!("Config: {}", config_path.display());
    eprintln!();
    eprintln!("  Write Key: {}", if write_key.is_empty() { "(not set)" } else { &write_key });
    eprintln!();
    eprintln!("  Plugins:");
    for p in PLUGIN_REGISTRY {
        let marker = if enabled.contains(p.key) { "+" } else { "-" };
        eprintln!("    {marker} {}", p.key);
    }

    ExitCode::SUCCESS
}

pub fn run_set(
    write_key: Option<String>,
    plugins: Option<Vec<String>>,
    add_plugins: Vec<String>,
    remove_plugins: Vec<String>,
) -> ExitCode {
    let (config_path, mut config) = match load_config() {
        Ok(v) => v,
        Err(code) => return code,
    };

    if let Some(key) = &write_key {
        config.set("SEGMENT_WRITE_KEY", key);
        info("Write key updated");
    }

    if plugins.is_some() || !add_plugins.is_empty() || !remove_plugins.is_empty() {
        let csv = match apply_plugin_changes(&config, &plugins, &add_plugins, &remove_plugins) {
            Ok(csv) => csv,
            Err(e) => {
                err(&e);
                return ExitCode::FAILURE;
            }
        };
        config.set("ENABLED_PLUGINS", &csv);
        info(&format!("Enabled plugins: {}", if csv.is_empty() { "(none)" } else { &csv }));
    }

    if let Err(e) = fs::write(&config_path, config.to_string()) {
        err(&format!("Failed to write {}: {}", config_path.display(), e));
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}
