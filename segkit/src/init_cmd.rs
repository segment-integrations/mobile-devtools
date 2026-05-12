use std::fs;
use std::io::{self, BufRead, IsTerminal, Write};
use std::path::PathBuf;
use std::process::{Command, ExitCode};

use crate::doctor;
use crate::util::fs::write_file;
use crate::util::log::{err, info};

pub struct Plugin {
    /// CLI name (e.g. "amplitude")
    pub key: &'static str,
    /// Human-readable display name
    pub display_name: &'static str,
    /// SPM package name used in project.yml
    pub package_name: &'static str,
    /// GitHub repo URL
    pub repo_url: &'static str,
    /// Minimum version for SPM
    pub min_version: &'static str,
    /// Swift import name
    pub import_name: &'static str,
    /// Swift class instantiation expression (e.g. "AmplitudeSession()")
    pub swift_init: &'static str,
}

pub const PLUGIN_REGISTRY: &[Plugin] = &[
    Plugin {
        key: "amplitude",
        display_name: "Amplitude",
        package_name: "SegmentAmplitude",
        repo_url: "https://github.com/segment-integrations/analytics-swift-amplitude",
        min_version: "1.5.0",
        import_name: "SegmentAmplitude",
        swift_init: "AmplitudeSession()",
    },
    Plugin {
        key: "appsflyer",
        display_name: "AppsFlyer",
        package_name: "SegmentAppsFlyer",
        repo_url: "https://github.com/segment-integrations/analytics-swift-appsflyer",
        min_version: "1.3.0",
        import_name: "SegmentAppsFlyer",
        swift_init: "AppsFlyerDestination()",
    },
    Plugin {
        key: "braze",
        display_name: "Braze",
        package_name: "SegmentBraze",
        repo_url: "https://github.com/segment-integrations/analytics-swift-braze",
        min_version: "2.2.0",
        import_name: "SegmentBraze",
        swift_init: "BrazeDestination()",
    },
    Plugin {
        key: "facebook",
        display_name: "Facebook",
        package_name: "SegmentFacebook",
        repo_url: "https://github.com/segment-integrations/analytics-swift-facebook-app-events",
        min_version: "1.1.3",
        import_name: "SegmentFacebook",
        swift_init: "FacebookAppEventsDestination()",
    },
    Plugin {
        key: "firebase",
        display_name: "Firebase",
        package_name: "SegmentFirebase",
        repo_url: "https://github.com/segment-integrations/analytics-swift-firebase",
        min_version: "1.4.0",
        import_name: "SegmentFirebase",
        swift_init: "FirebaseDestination()",
    },
    Plugin {
        key: "mixpanel",
        display_name: "Mixpanel",
        package_name: "SegmentMixpanel",
        repo_url: "https://github.com/segment-integrations/analytics-swift-mixpanel",
        min_version: "1.1.3",
        import_name: "SegmentMixpanel",
        swift_init: "MixpanelDestination()",
    },
    Plugin {
        key: "survicate",
        display_name: "Survicate",
        package_name: "SegmentSurvicate",
        repo_url: "https://github.com/Survicate/analytics-swift-survicate",
        min_version: "3.0.2",
        import_name: "SegmentSurvicate",
        swift_init: "SurvicateDestination()",
    },
];

/// Validate that all plugin names are known. Returns an error message for the first unknown name.
pub fn validate_plugin_names(names: &[String]) -> Result<(), String> {
    for name in names {
        let lower = name.to_lowercase();
        if !PLUGIN_REGISTRY.iter().any(|p| p.key == lower) {
            let available: Vec<_> = PLUGIN_REGISTRY.iter().map(|p| p.key).collect();
            return Err(format!(
                "Unknown plugin '{name}'. Available: {}",
                available.join(", ")
            ));
        }
    }
    Ok(())
}

fn resolve_plugins(requested: &[String]) -> Result<Vec<&'static Plugin>, String> {
    let mut resolved = Vec::new();
    for name in requested {
        let lower = name.to_lowercase();
        match PLUGIN_REGISTRY.iter().find(|p| p.key == lower) {
            Some(p) => resolved.push(p),
            None => {
                let available: Vec<_> = PLUGIN_REGISTRY.iter().map(|p| p.key).collect();
                return Err(format!(
                    "Unknown plugin '{name}'. Available: {}",
                    available.join(", ")
                ));
            }
        }
    }
    resolved.dedup_by_key(|p| p.key);
    Ok(resolved)
}

/// Check if a name is a valid Swift identifier (ASCII letters, digits, underscores; not starting with a digit).
fn is_valid_swift_identifier(name: &str) -> bool {
    if name.is_empty() {
        return false;
    }
    let mut chars = name.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

fn ensure_xcodegen() -> bool {
    if which::which("xcodegen").is_ok() {
        return true;
    }
    info("Installing xcodegen...");
    let status = Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "profile",
            "install",
            "nixpkgs#xcodegen",
        ])
        .status();
    match status {
        Ok(s) if s.success() => true,
        _ => {
            err("Failed to install xcodegen via nix.");
            false
        }
    }
}

fn apply(template: &str, name: &str, org: &str, write_key: &str, bundle_id: &str) -> String {
    template
        .replace("__NAME__", name)
        .replace("__ORG__", org)
        .replace("__WRITE_KEY__", write_key)
        .replace("__BUNDLE_ID__", bundle_id)
}

/// Generate the packages section of project.yml for selected plugins.
fn generate_packages_yaml(plugins: &[&Plugin]) -> String {
    let mut yaml = String::new();
    for p in plugins {
        yaml.push_str(&format!(
            "  {}:\n    url: {}\n    from: {}\n",
            p.package_name, p.repo_url, p.min_version
        ));
    }
    yaml
}

/// Generate the dependencies section entries for selected plugins.
fn generate_deps_yaml(plugins: &[&Plugin]) -> String {
    let mut yaml = String::new();
    for p in plugins {
        yaml.push_str(&format!("      - package: {}\n", p.package_name));
    }
    yaml
}

/// Generate the project.yml with dynamic plugin support.
fn generate_project_yml(name: &str, org: &str, plugins: &[&Plugin]) -> String {
    let mut packages_section = String::new();
    packages_section.push_str("  Segment:\n    url: https://github.com/segmentio/analytics-swift\n    from: 1.9.3\n");
    packages_section.push_str(&generate_packages_yaml(plugins));

    let mut deps_section = String::from("      - package: Segment\n");
    deps_section.push_str(&generate_deps_yaml(plugins));

    format!(
        r#"name: {name}
options:
  bundleIdPrefix: {org}
  deploymentTarget:
    iOS: "16.0"
  generateEmptyDirectories: true
packages:
{packages}targets:
  {name}:
    type: application
    platform: iOS
    sources: [{name}]
    dependencies:
{deps}    settings:
      GENERATE_INFOPLIST_FILE: YES
      INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
      INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: YES
      INFOPLIST_KEY_UILaunchScreen_Generation: YES
      INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
      INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
      SWIFT_EMIT_LOC_STRINGS: YES
      CLANG_ENABLE_EXPLICIT_MODULES: NO
  {name}Tests:
    type: bundle.unit-test
    platform: iOS
    sources: [{name}Tests]
    dependencies:
      - target: {name}
    settings:
      GENERATE_INFOPLIST_FILE: YES
  {name}UITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [{name}UITests]
    dependencies:
      - target: {name}
    settings:
      GENERATE_INFOPLIST_FILE: YES
"#,
        name = name,
        org = org,
        packages = packages_section,
        deps = deps_section,
    )
}

/// Generate the SegmentConfig.xcconfig file content.
pub fn generate_xcconfig(write_key: &str, enabled_plugins: &[String]) -> String {
    let plugins_csv = enabled_plugins.join(",");
    format!(
        r#"// Segment SDK Configuration
// Managed by segkit - manual edits are fine

SEGMENT_WRITE_KEY = {write_key}
ENABLED_PLUGINS = {plugins_csv}
"#,
        write_key = write_key,
        plugins_csv = plugins_csv,
    )
}

/// Generate ContentView.swift with all plugin imports and dynamic registration.
fn generate_content_view(name: &str) -> String {
    // All 7 plugin imports — always present
    let mut imports = String::from("import Segment\n");
    for p in PLUGIN_REGISTRY {
        imports.push_str(&format!("import {}\n", p.import_name));
    }

    // Build the availablePlugins array entries
    let mut plugin_entries = String::new();
    for p in PLUGIN_REGISTRY {
        plugin_entries.push_str(&format!(
            "            (\"{key}\", \"{display}\", {{ {init} as (any DestinationPlugin) }}),\n",
            key = p.key,
            display = p.display_name,
            init = p.swift_init,
        ));
    }

    // Build the allPlugins struct data
    let mut all_plugins_data = String::new();
    for p in PLUGIN_REGISTRY {
        all_plugins_data.push_str(&format!(
            "        PluginInfo(key: \"{key}\", name: \"{display}\"),\n",
            key = p.key,
            display = p.display_name,
        ));
    }

    format!(
        r#"//
//  ContentView.swift
//  {name}
//

import SwiftUI
{imports}
struct PluginInfo: Identifiable {{
    let key: String
    let name: String
    var id: String {{ key }}
}}

struct ContentView: View {{
    @State private var eventCount = 0
    @State private var lastEventTime: Date?

    let analytics: Analytics

    private let allPlugins: [PluginInfo] = [
{all_plugins_data}    ]

    init() {{
        var configuration = Configuration(writeKey: Config.segmentWriteKey)

        if Config.isUsingDemoKey {{
            configuration = configuration
                .flushAt(1000)
                .flushInterval(0)
        }} else {{
            configuration = configuration
                .flushInterval(10)
        }}

        self.analytics = Analytics(configuration: configuration)
        analytics.add(plugin: ConsoleLoggerPlugin())
        analytics.add(plugin: IDFAPlugin())

        // Dynamically register enabled destination plugins
        let availablePlugins: [(key: String, name: String, make: () -> any DestinationPlugin)] = [
{plugin_entries}        ]
        for p in availablePlugins where Config.enabledPluginKeys.contains(p.key) {{
            analytics.add(plugin: p.make())
            print("  Enabled destination: \(p.name)")
        }}

        print("Segment Analytics initialized")
        print("  Write Key: \(Config.segmentWriteKey)")
        print("  Mode: \(Config.isUsingDemoKey ? "Demo (events queued locally)" : "Live (sending to Segment)")")
        print("  Enabled plugins: \(Config.enabledPluginKeys.sorted().joined(separator: ", "))")
    }}

    var body: some View {{
        VStack(spacing: 24) {{
            VStack(spacing: 8) {{
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Segment iOS Demo")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Analytics Swift SDK")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }}
            .padding(.top, 40)

            Spacer()

            VStack(spacing: 4) {{
                Text("\(eventCount)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.blue)

                Text("Events Tracked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let lastTime = lastEventTime {{
                    Text("Last: \(lastTime, formatter: dateFormatter)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }}
            }}
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.1))
            )

            Spacer()

            VStack(spacing: 16) {{
                Button(action: trackEvent) {{
                    HStack {{
                        Image(systemName: "chart.bar.fill")
                        Text("Track Event")
                    }}
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }}

                Button(action: identifyUser) {{
                    HStack {{
                        Image(systemName: "person.fill")
                        Text("Identify User")
                    }}
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }}

                Button(action: trackScreen) {{
                    HStack {{
                        Image(systemName: "iphone")
                        Text("Track Screen")
                    }}
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.purple)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }}
            }}
            .padding(.horizontal, 32)

            // Plugin status list
            VStack(spacing: 8) {{
                Divider()
                Text("Destination Plugins")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(allPlugins) {{ plugin in
                    let isEnabled = Config.enabledPluginKeys.contains(plugin.key)
                    HStack {{
                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isEnabled ? .green : .gray)
                        Text(plugin.name)
                            .font(.subheadline)
                        Spacer()
                        Text(isEnabled ? "Enabled" : "Available")
                            .font(.caption)
                            .foregroundStyle(isEnabled ? .green : .secondary)
                    }}
                }}
            }}
            .padding(.horizontal, 32)

            Spacer()
        }}
        .padding()
    }}

    private func trackEvent() {{
        eventCount += 1
        lastEventTime = Date()

        analytics.track(name: "Button Pressed", properties: [
            "button": "Track Event",
            "count": eventCount,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }}

    private func identifyUser() {{
        eventCount += 1
        lastEventTime = Date()

        analytics.identify(userId: "demo-user-\(UUID().uuidString.prefix(8))", traits: [
            "name": "Demo User",
            "email": "demo@example.com",
            "plan": "free",
            "event_count": eventCount
        ])
    }}

    private func trackScreen() {{
        eventCount += 1
        lastEventTime = Date()

        analytics.screen(title: "Demo Screen", properties: [
            "screen_name": "ContentView",
            "view_count": eventCount
        ])
    }}

    private var dateFormatter: DateFormatter {{
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }}
}}

#Preview {{
    ContentView()
}}
"#,
        name = name,
        imports = imports,
        all_plugins_data = all_plugins_data,
        plugin_entries = plugin_entries,
    )
}

/// Prompt the user for input with a default value. Returns the default in non-interactive mode.
fn prompt(label: &str, default: &str) -> String {
    if !io::stdin().is_terminal() {
        return default.to_string();
    }
    if default.is_empty() {
        eprint!("{label}: ");
    } else {
        eprint!("{label} [{default}]: ");
    }
    io::stderr().flush().ok();

    let mut line = String::new();
    if io::stdin().lock().read_line(&mut line).is_err() {
        return default.to_string();
    }
    let trimmed = line.trim();
    if trimmed.is_empty() { default.to_string() } else { trimmed.to_string() }
}

/// Prompt user to select plugins interactively (toggle with numbers, Enter to confirm).
fn prompt_plugins(already_selected: &[String]) -> Vec<String> {
    if !io::stdin().is_terminal() {
        return already_selected.to_vec();
    }

    let mut selected: Vec<bool> = PLUGIN_REGISTRY
        .iter()
        .map(|p| already_selected.iter().any(|s| s.to_lowercase() == p.key))
        .collect();

    loop {
        eprintln!();
        eprintln!("Select destination plugins (enter numbers to toggle, Enter to confirm):");
        for (i, plugin) in PLUGIN_REGISTRY.iter().enumerate() {
            let marker = if selected[i] { "[x]" } else { "[ ]" };
            eprintln!("  {}) {} {}", i + 1, marker, plugin.key);
        }
        eprint!("> ");
        io::stderr().flush().ok();

        let mut line = String::new();
        if io::stdin().lock().read_line(&mut line).is_err() {
            break;
        }
        let trimmed = line.trim();
        if trimmed.is_empty() {
            break;
        }
        for token in trimmed.split_whitespace() {
            if let Ok(n) = token.parse::<usize>() {
                if n >= 1 && n <= PLUGIN_REGISTRY.len() {
                    selected[n - 1] = !selected[n - 1];
                }
            }
        }
    }

    PLUGIN_REGISTRY
        .iter()
        .enumerate()
        .filter(|(i, _)| selected[*i])
        .map(|(_, p)| p.key.to_string())
        .collect()
}

pub fn run(
    sdk: Option<String>,
    name: Option<String>,
    org: Option<String>,
    write_key: Option<String>,
    plugin_names: Vec<String>,
) -> ExitCode {
    let interactive = io::stdin().is_terminal();

    // If any required field is missing and we're interactive, run the wizard
    let needs_wizard = interactive && sdk.is_none();

    let sdk = sdk.unwrap_or_else(|| {
        if interactive {
            prompt("SDK template (swift)", "swift")
        } else {
            err("--sdk is required in non-interactive mode");
            std::process::exit(1);
        }
    });

    if sdk != "swift" {
        err(&format!("Unknown SDK: {sdk}. Only 'swift' is supported."));
        return ExitCode::FAILURE;
    }

    let name = name.unwrap_or_else(|| prompt("Project name", "SegmentDemo"));

    // Project name must be a valid Swift identifier (letters, digits, underscores)
    if !is_valid_swift_identifier(&name) {
        err(&format!(
            "Project name '{name}' is not a valid Swift identifier. \
             Use only letters, digits, and underscores (e.g. SegmentDemo, my_app)."
        ));
        return ExitCode::FAILURE;
    }

    let org = org.unwrap_or_else(|| prompt("Organization identifier", "com.example"));
    let write_key = write_key.unwrap_or_else(|| prompt("Segment write key", "demo_write_key_not_real"));

    let plugin_names = if needs_wizard && plugin_names.is_empty() {
        prompt_plugins(&plugin_names)
    } else {
        plugin_names
    };

    // Resolve requested plugins
    let plugins = match resolve_plugins(&plugin_names) {
        Ok(p) => p,
        Err(e) => {
            err(&e);
            return ExitCode::FAILURE;
        }
    };

    if !plugins.is_empty() {
        let names: Vec<_> = plugins.iter().map(|p| p.key).collect();
        info(&format!("Plugins: {}", names.join(", ")));
    }

    let bundle_id = format!("{org}.{name}");
    let out = PathBuf::from(&name);

    if out.exists() {
        err(&format!("Directory '{}' already exists.", out.display()));
        return ExitCode::FAILURE;
    }

    if !ensure_xcodegen() {
        return ExitCode::FAILURE;
    }

    info(&format!("Creating {name} from swift template..."));
    fs::create_dir_all(&out).unwrap_or_else(|e| {
        err(&format!("Failed to create directory: {e}"));
    });

    // project.yml — always includes all 7 plugins as SPM dependencies
    let all_plugins: Vec<&Plugin> = PLUGIN_REGISTRY.iter().collect();
    write_file(&out, "project.yml", &generate_project_yml(&name, &org, &all_plugins));

    // devbox.json
    write_file(&out, "devbox.json", &apply(DEVBOX_JSON, &name, &org, &write_key, &bundle_id));

    // Device definitions
    write_file(&out, "devbox.d/ios/devices/max.json", DEVICE_MAX_JSON);
    write_file(&out, "devbox.d/ios/devices/min.json", DEVICE_MIN_JSON);

    // Swift source files
    let src = &name;
    // SegmentConfig.xcconfig — runtime config read by Config.swift
    let enabled_keys: Vec<String> = plugins.iter().map(|p| p.key.to_string()).collect();
    write_file(&out, &format!("{src}/SegmentConfig.xcconfig"), &generate_xcconfig(&write_key, &enabled_keys));

    write_file(&out, &format!("{src}/Config.swift"), &apply(CONFIG_SWIFT, &name, &org, &write_key, &bundle_id));
    write_file(&out, &format!("{src}/{name}App.swift"), &apply(APP_SWIFT, &name, &org, &write_key, &bundle_id));
    write_file(&out, &format!("{src}/ContentView.swift"), &generate_content_view(&name));
    write_file(&out, &format!("{src}/ConsoleLoggerPlugin.swift"), CONSOLE_LOGGER_SWIFT);
    write_file(&out, &format!("{src}/IDFAPlugin.swift"), IDFA_PLUGIN_SWIFT);

    // Asset catalogs
    write_file(&out, &format!("{src}/Assets.xcassets/Contents.json"), ASSETS_CONTENTS);
    write_file(&out, &format!("{src}/Assets.xcassets/AccentColor.colorset/Contents.json"), ACCENT_COLOR_CONTENTS);
    write_file(&out, &format!("{src}/Assets.xcassets/AppIcon.appiconset/Contents.json"), APP_ICON_CONTENTS);

    // Test files
    write_file(&out, &format!("{name}Tests/{name}Tests.swift"), &apply(TESTS_SWIFT, &name, &org, &write_key, &bundle_id));
    write_file(&out, &format!("{name}UITests/{name}UITests.swift"), &apply(UI_TESTS_SWIFT, &name, &org, &write_key, &bundle_id));
    write_file(&out, &format!("{name}UITests/{name}UITestsLaunchTests.swift"), &apply(UI_TESTS_LAUNCH_SWIFT, &name, &org, &write_key, &bundle_id));

    // .gitignore
    write_file(&out, ".gitignore", GITIGNORE);

    // scripts
    write_file(&out, "scripts/share.sh", SHARE_SH);

    // Generate Xcode project
    info("Generating Xcode project...");
    let status = Command::new("xcodegen")
        .args(["generate", "--spec", "project.yml"])
        .current_dir(&out)
        .status();

    match status {
        Ok(s) if s.success() => {}
        Ok(s) => {
            err(&format!(
                "xcodegen exited with code {}",
                s.code().unwrap_or(-1)
            ));
            return ExitCode::FAILURE;
        }
        Err(e) => {
            err(&format!("Failed to run xcodegen: {e}"));
            return ExitCode::FAILURE;
        }
    }

    // Run doctor --fix to ensure devbox/homebrew/etc. are available
    info("Running doctor --fix to ensure dependencies are installed...");
    let doctor_result = doctor::run(true);
    if doctor_result != ExitCode::SUCCESS {
        err("doctor --fix reported issues; the project was still created.");
    }

    info("Done!");
    eprintln!();
    eprintln!("  cd {name}");
    eprintln!("  devbox run start:app");
    eprintln!();

    ExitCode::SUCCESS
}

// ============================================================================
// Templates
// ============================================================================

// project.yml is now generated dynamically by generate_project_yml()

const DEVBOX_JSON: &str = r#"{
  "include": ["github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"],
  "packages": {
    "process-compose": "latest"
  },
  "env": {
    "IOS_APP_ARTIFACT": "DerivedData/Build/Products/Debug-iphonesimulator/__NAME__.app"
  },
  "shell": {
    "scripts": {
      "build": [
        "ios.sh xcodebuild -project __NAME__.xcodeproj -scheme __NAME__ -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build"
      ],
      "build:release": [
        "ios.sh xcodebuild -project __NAME__.xcodeproj -scheme __NAME__ -configuration Release -derivedDataPath DerivedData build"
      ],
      "build:clean": [
        "rm -rf DerivedData"
      ],
      "start:app": [
        "ios.sh run ${1:-}"
      ],
      "test": [
        "ios.sh xcodebuild -project __NAME__.xcodeproj -scheme __NAME__ -destination 'platform=iOS Simulator,name=iPhone 17' test"
      ]
    }
  }
}
"#;

const DEVICE_MAX_JSON: &str = r#"{
  "name": "iPhone 17",
  "runtime": "26.5"
}
"#;

const DEVICE_MIN_JSON: &str = r#"{
  "name": "iPhone 16",
  "runtime": "18.5"
}
"#;

const CONFIG_SWIFT: &str = r#"//
//  Config.swift
//  __NAME__
//

import Foundation

enum Config {
    private static let configValues: [String: String] = {
        guard let url = Bundle.main.url(forResource: "SegmentConfig", withExtension: "xcconfig"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var dict: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                dict[key] = value
            }
        }
        return dict
    }()

    /// Segment write key — read from SegmentConfig.xcconfig
    static let segmentWriteKey: String = configValues["SEGMENT_WRITE_KEY"] ?? "demo_write_key_not_real"

    /// Set of enabled plugin keys — read from SegmentConfig.xcconfig
    static let enabledPluginKeys: Set<String> = {
        guard let raw = configValues["ENABLED_PLUGINS"], !raw.isEmpty else { return [] }
        return Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }()

    /// Check if using demo/placeholder key
    static var isUsingDemoKey: Bool {
        segmentWriteKey.isEmpty ||
        segmentWriteKey == "demo_write_key_not_real" ||
        segmentWriteKey == "YOUR_WRITE_KEY_HERE"
    }
}
"#;

const APP_SWIFT: &str = r#"//
//  __NAME__App.swift
//  __NAME__
//

import SwiftUI

@main
struct __NAME__App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
"#;

// ContentView.swift is now generated dynamically by generate_content_view()

const CONSOLE_LOGGER_SWIFT: &str = r#"//
//  ConsoleLoggerPlugin.swift
//

import Foundation
import Segment

class ConsoleLoggerPlugin: Plugin {
    let type: PluginType = .enrichment
    weak var analytics: Analytics?

    func execute<T>(event: T?) -> T? where T : RawEvent {
        guard let event = event else { return event }

        switch event {
        case let trackEvent as TrackEvent:
            print("Track Event: \(trackEvent.event)")
            if let properties = trackEvent.properties {
                print("  Properties: \(properties)")
            }

        case let identifyEvent as IdentifyEvent:
            print("Identify: \(identifyEvent.userId ?? "anonymous")")
            if let traits = identifyEvent.traits {
                print("  Traits: \(traits)")
            }

        case let screenEvent as ScreenEvent:
            print("Screen: \(screenEvent.name ?? "Unknown")")
            if let properties = screenEvent.properties {
                print("  Properties: \(properties)")
            }

        case let groupEvent as GroupEvent:
            print("Group: \(groupEvent.groupId)")
            if let traits = groupEvent.traits {
                print("  Traits: \(traits)")
            }

        case let aliasEvent as AliasEvent:
            print("Alias: \(aliasEvent.userId) -> \(aliasEvent.previousId ?? "none")")

        default:
            print("Event: \(Swift.type(of: event))")
        }

        return event
    }
}
"#;

const IDFA_PLUGIN_SWIFT: &str = r#"//
//  IDFAPlugin.swift
//

import Foundation
import Segment
import AdSupport
import AppTrackingTransparency

class IDFAPlugin: Plugin {
    let type: PluginType = .enrichment
    weak var analytics: Analytics?

    func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }

        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            if status == .notDetermined {
                return event
            }
        }

        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString

        var context = workingEvent.context?.dictionaryValue ?? [:]
        var device = (context["device"] as? [String: Any]) ?? [:]
        device["advertisingId"] = idfa
        device["adTrackingEnabled"] = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
        context["device"] = device

        do {
            workingEvent.context = try JSON(context)
        } catch {
            print("Failed to update context with IDFA: \(error)")
        }

        return workingEvent
    }
}
"#;

const TESTS_SWIFT: &str = r#"//
//  __NAME__Tests.swift
//  __NAME__Tests
//

import XCTest
@testable import __NAME__

final class __NAME__Tests: XCTestCase {

    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func testContentViewExists() throws {
        let view = ContentView()
        XCTAssertNotNil(view)
    }

    func testPerformanceExample() throws {
        self.measure {
            let _ = (0..<1000).map { $0 * 2 }
        }
    }
}
"#;

const UI_TESTS_SWIFT: &str = r#"//
//  __NAME__UITests.swift
//  __NAME__UITests
//

import XCTest

final class __NAME__UITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
"#;

const UI_TESTS_LAUNCH_SWIFT: &str = r#"//
//  __NAME__UITestsLaunchTests.swift
//  __NAME__UITests
//

import XCTest

final class __NAME__UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
"#;

const ASSETS_CONTENTS: &str = r#"{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"#;

const ACCENT_COLOR_CONTENTS: &str = r#"{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"#;

const APP_ICON_CONTENTS: &str = r#"{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"#;

const GITIGNORE: &str = r#"# Xcode
DerivedData/
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.moved-aside
*.xccheckout
*.xcscmblueprint

# Devbox
.devbox/
"#;

const SHARE_SH: &str = r#"#!/usr/bin/env bash
set -euo pipefail

echo "Packaging project for sharing..."

COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
ARCHIVE_NAME="swift-repro-${COMMIT_HASH}-${TIMESTAMP}.zip"

zip -r "$ARCHIVE_NAME" . \
  -x '.git/*' \
  -x 'DerivedData/*' \
  -x '*.xcuserstate' \
  -x 'xcuserdata/*' \
  -x '.DS_Store' \
  -x '.devbox/*'

echo "Created: $ARCHIVE_NAME"
"#;
