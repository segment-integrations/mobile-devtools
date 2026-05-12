use std::collections::BTreeSet;
use std::fs;
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

pub fn run_show() -> ExitCode {
    let config_path = match find_file("SegmentConfig.xcconfig") {
        Some(p) => p,
        None => {
            err("No SegmentConfig.xcconfig found. Are you in a segkit project directory?");
            return ExitCode::FAILURE;
        }
    };

    let content = match fs::read_to_string(&config_path) {
        Ok(c) => c,
        Err(e) => {
            err(&format!("Failed to read {}: {}", config_path.display(), e));
            return ExitCode::FAILURE;
        }
    };

    let config = XCConfig::parse(&content);

    let write_key = config.get("SEGMENT_WRITE_KEY").unwrap_or_default();
    let plugins_raw = config.get("ENABLED_PLUGINS").unwrap_or_default();
    let enabled = parse_plugin_csv(&plugins_raw);

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
    let config_path = match find_file("SegmentConfig.xcconfig") {
        Some(p) => p,
        None => {
            err("No SegmentConfig.xcconfig found. Are you in a segkit project directory?");
            return ExitCode::FAILURE;
        }
    };

    let content = match fs::read_to_string(&config_path) {
        Ok(c) => c,
        Err(e) => {
            err(&format!("Failed to read {}: {}", config_path.display(), e));
            return ExitCode::FAILURE;
        }
    };

    let mut config = XCConfig::parse(&content);

    // Set write key if provided
    if let Some(key) = &write_key {
        config.set("SEGMENT_WRITE_KEY", key);
        info("Write key updated");
    }

    // Handle plugin mutations
    let has_plugin_change = plugins.is_some() || !add_plugins.is_empty() || !remove_plugins.is_empty();

    if has_plugin_change {
        // Validate all plugin names
        if let Some(ref list) = plugins {
            if let Err(e) = validate_plugin_names(list) {
                err(&e);
                return ExitCode::FAILURE;
            }
        }
        if let Err(e) = validate_plugin_names(&add_plugins) {
            err(&e);
            return ExitCode::FAILURE;
        }
        if let Err(e) = validate_plugin_names(&remove_plugins) {
            err(&e);
            return ExitCode::FAILURE;
        }

        let mut current = if let Some(ref list) = plugins {
            // --plugins replaces the entire list
            list.iter().map(|s| s.to_lowercase()).collect::<BTreeSet<String>>()
        } else {
            let raw = config.get("ENABLED_PLUGINS").unwrap_or_default();
            parse_plugin_csv(&raw)
        };

        // --add-plugins appends
        for p in &add_plugins {
            current.insert(p.to_lowercase());
        }

        // --remove-plugins removes
        for p in &remove_plugins {
            current.remove(&p.to_lowercase());
        }

        let csv = current.into_iter().collect::<Vec<_>>().join(",");
        config.set("ENABLED_PLUGINS", &csv);
        info(&format!("Enabled plugins: {}", if csv.is_empty() { "(none)" } else { &csv }));
    }

    // Write back
    if let Err(e) = fs::write(&config_path, config.to_string()) {
        err(&format!("Failed to write {}: {}", config_path.display(), e));
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}
