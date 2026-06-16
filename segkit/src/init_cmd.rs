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
        package_name: "SurvicateDestination",
        repo_url: "https://github.com/Survicate/analytics-swift-survicate",
        min_version: "3.0.2",
        import_name: "SurvicateDestination",
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

/// Generate the SegmentConfig.conf file content.
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
            "            (\"{key}\", \"{display}\", {{ {init} as (any Plugin) }}),\n",
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
    @State private var eventsSent = 0
    @State private var lastEventTime: Date?
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var autoFlush = true

    let analytics: Analytics
    private let loadedPluginKeys: Set<String>

    private let allPlugins: [PluginInfo] = [
{all_plugins_data}    ]

    init() {{
        let configuration = Configuration(writeKey: Config.segmentWriteKey)
            .flushAt(999999)
            .flushInterval(0)

        self.analytics = Analytics(configuration: configuration)
        analytics.add(plugin: ConsoleLoggerPlugin())
        analytics.add(plugin: IDFAPlugin())

        // Dynamically register enabled destination plugins
        var loaded = Set<String>()
        let availablePlugins: [(key: String, name: String, make: () -> any Plugin)] = [
{plugin_entries}        ]
        for p in availablePlugins where Config.enabledPluginKeys.contains(p.key) {{
            analytics.add(plugin: p.make())
            loaded.insert(p.key)
            print("  Enabled destination: \(p.name)")
        }}
        self.loadedPluginKeys = loaded

        print("Segment Analytics initialized")
        print("  Write Key: \(Config.segmentWriteKey.prefix(8))...")
        print("  Mode: \(Config.isUsingDemoKey ? "Demo (events queued locally)" : "Live (sending to Segment)")")
        print("  Enabled plugins: \(Config.enabledPluginKeys.sorted().joined(separator: ", "))")
    }}

    private var eventsInQueue: Int {{
        max(eventCount - eventsSent, 0)
    }}

    var body: some View {{
        ScrollView {{
            VStack(spacing: 20) {{
                // Header
                VStack(spacing: 6) {{
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("Segment iOS Demo")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Analytics Swift SDK")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }}
                .padding(.top, 24)

                // Connection status
                HStack(spacing: 8) {{
                    Image(systemName: connectionStatus.icon)
                        .foregroundStyle(connectionStatus.color)
                    Text(connectionStatus.label)
                        .font(.subheadline)
                        .foregroundStyle(connectionStatus.color)
                    Spacer()
                    if connectionStatus != .checking {{
                        Button("Recheck") {{ checkConnection() }}
                            .font(.caption)
                    }}
                }}
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(connectionStatus.color.opacity(0.1))
                )
                .padding(.horizontal, 32)

                // Stats
                HStack(spacing: 16) {{
                    statBox(title: "Tracked", value: "\(eventCount)", color: .blue)
                    statBox(title: "In Queue", value: "\(eventsInQueue)", color: .orange)
                    statBox(title: "Sent", value: "\(eventsSent)", color: .green)
                }}
                .padding(.horizontal, 32)

                if let lastTime = lastEventTime {{
                    Text("Last event: \(lastTime, formatter: dateFormatter)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }}

                // Track buttons
                VStack(spacing: 12) {{
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

                // Flush controls
                VStack(spacing: 10) {{
                    Divider()
                    HStack {{
                        Text("Flush Mode")
                            .font(.headline)
                        Spacer()
                        Picker("", selection: $autoFlush) {{
                            Text("Auto").tag(true)
                            Text("Manual").tag(false)
                        }}
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }}

                    if !autoFlush {{
                        Button(action: flushEvents) {{
                            HStack {{
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Flush Now")
                                if eventsInQueue > 0 {{
                                    Text("(\(eventsInQueue))")
                                }}
                            }}
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(eventsInQueue > 0 ? .orange : .gray)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }}
                        .disabled(eventsInQueue == 0)
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
                        let isLoaded = loadedPluginKeys.contains(plugin.key)
                        let statusIcon = isLoaded ? "checkmark.circle.fill" : isEnabled ? "exclamationmark.circle.fill" : "circle"
                        let statusColor: Color = isLoaded ? .green : isEnabled ? .red : .gray
                        let statusLabel = isLoaded ? "Running" : isEnabled ? "Error" : "Available"
                        HStack {{
                            Image(systemName: statusIcon)
                                .foregroundStyle(statusColor)
                            Text(plugin.name)
                                .font(.subheadline)
                            Spacer()
                            Text(statusLabel)
                                .font(.caption)
                                .foregroundStyle(statusColor)
                        }}
                    }}
                }}
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }}
        }}
        .onAppear {{ checkConnection() }}
    }}

    private func statBox(title: String, value: String, color: Color) -> some View {{
        VStack(spacing: 4) {{
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }}
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }}

    private func checkConnection() {{
        connectionStatus = .checking
        Config.validateConnection {{ status in
            connectionStatus = status
        }}
    }}

    private func afterEvent() {{
        if autoFlush && !Config.isUsingDemoKey {{
            analytics.flush()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {{
                eventsSent = eventCount
            }}
        }}
    }}

    private func flushEvents() {{
        analytics.flush()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {{
            eventsSent = eventCount
        }}
    }}

    private func trackEvent() {{
        eventCount += 1
        lastEventTime = Date()

        analytics.track(name: "Button Pressed", properties: [
            "button": "Track Event",
            "count": eventCount,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        afterEvent()
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
        afterEvent()
    }}

    private func trackScreen() {{
        eventCount += 1
        lastEventTime = Date()

        analytics.screen(title: "Demo Screen", properties: [
            "screen_name": "ContentView",
            "view_count": eventCount
        ])
        afterEvent()
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
        eprintln!("Select destination plugins (numbers to toggle, all/none, Enter to confirm):");
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
        for token in trimmed.split(|c: char| c == ',' || c.is_whitespace()) {
            let token = token.trim();
            if token.is_empty() {
                continue;
            }
            match token.to_lowercase().as_str() {
                "all" => selected.iter_mut().for_each(|s| *s = true),
                "none" => selected.iter_mut().for_each(|s| *s = false),
                _ => {
                    if let Ok(n) = token.parse::<usize>() {
                        if n >= 1 && n <= PLUGIN_REGISTRY.len() {
                            selected[n - 1] = !selected[n - 1];
                        }
                    }
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
            prompt("SDK template (swift, flutter)", "swift")
        } else {
            err("--sdk is required in non-interactive mode");
            std::process::exit(1);
        }
    });

    if sdk == "flutter" {
        let name = name.unwrap_or_else(|| prompt("Project name", "segment_demo"));
        let org = org.unwrap_or_else(|| prompt("Organization identifier", "com.example"));
        let write_key = write_key.unwrap_or_else(|| prompt("Segment write key", "demo_write_key_not_real"));
        return init_flutter(name, org, write_key, plugin_names, needs_wizard);
    }

    if sdk != "swift" {
        err(&format!("Unknown SDK: {sdk}. Supported: swift, flutter."));
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
    // SegmentConfig.conf — runtime config read by Config.swift
    // Uses .conf extension so Xcode bundles it as a resource (not a build config)
    let enabled_keys: Vec<String> = plugins.iter().map(|p| p.key.to_string()).collect();
    write_file(&out, &format!("{src}/SegmentConfig.conf"), &generate_xcconfig(&write_key, &enabled_keys));

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
        "ios.sh xcodebuild -project __NAME__.xcodeproj -scheme __NAME__ -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData CLANG_ENABLE_EXPLICIT_MODULES=NO build"
      ],
      "build:release": [
        "ios.sh xcodebuild -project __NAME__.xcodeproj -scheme __NAME__ -configuration Release -derivedDataPath DerivedData CLANG_ENABLE_EXPLICIT_MODULES=NO build"
      ],
      "build:clean": [
        "rm -rf DerivedData"
      ],
      "start:app": [
        "ios.sh run ${1:-}"
      ],
      "test": [
        "ios.sh xcodebuild -project __NAME__.xcodeproj -scheme __NAME__ -destination 'platform=iOS Simulator,name=iPhone 17' CLANG_ENABLE_EXPLICIT_MODULES=NO test"
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
import SwiftUI

enum Config {
    private static let configValues: [String: String] = {
        guard let url = Bundle.main.url(forResource: "SegmentConfig", withExtension: "conf"),
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

    /// Segment write key — read from SegmentConfig.conf
    static let segmentWriteKey: String = configValues["SEGMENT_WRITE_KEY"] ?? "demo_write_key_not_real"

    /// Set of enabled plugin keys — read from SegmentConfig.conf
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

    /// Validate the write key against Segment's API. Calls back on main thread.
    static func validateConnection(completion: @escaping (ConnectionStatus) -> Void) {
        guard !isUsingDemoKey else {
            DispatchQueue.main.async { completion(.demoMode) }
            return
        }
        var request = URLRequest(url: URL(string: "https://api.segment.io/v1/batch")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let credentials = "\(segmentWriteKey):".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "batch": [["type": "track", "event": "__segkit_ping", "userId": "segkit"]],
            "sentAt": ISO8601DateFormatter().string(from: Date()),
        ])
        URLSession.shared.dataTask(with: request) { _, response, error in
            let status: ConnectionStatus
            if let error = error {
                status = .error(error.localizedDescription)
            } else if let http = response as? HTTPURLResponse {
                switch http.statusCode {
                case 200: status = .connected
                case 401: status = .invalidKey
                default: status = .error("HTTP \(http.statusCode)")
                }
            } else {
                status = .error("No response")
            }
            DispatchQueue.main.async { completion(status) }
        }.resume()
    }
}

enum ConnectionStatus: Equatable {
    case unknown
    case checking
    case connected
    case invalidKey
    case demoMode
    case error(String)

    var label: String {
        switch self {
        case .unknown: return "Not checked"
        case .checking: return "Checking..."
        case .connected: return "Connected"
        case .invalidKey: return "Invalid write key"
        case .demoMode: return "Demo mode"
        case .error(let msg): return msg
        }
    }

    var color: SwiftUI.Color {
        switch self {
        case .connected: return .green
        case .invalidKey, .error: return .red
        case .demoMode: return .orange
        case .unknown, .checking: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .connected: return "checkmark.circle.fill"
        case .invalidKey, .error: return "xmark.circle.fill"
        case .demoMode: return "info.circle.fill"
        case .checking: return "arrow.triangle.2.circlepath"
        case .unknown: return "questionmark.circle"
        }
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

// ============================================================================
// Flutter support
// ============================================================================

struct FlutterPlugin {
    key: &'static str,
    package_name: &'static str,
    min_version: &'static str,
    import_name: &'static str,
    class_name: &'static str,
}

const FLUTTER_PLUGIN_REGISTRY: &[FlutterPlugin] = &[
    FlutterPlugin {
        key: "amplitude",
        package_name: "segment_analytics_plugin_amplitude",
        min_version: "1.0.0",
        import_name: "plugin_amplitude",
        class_name: "amplitudeDestination",
    },
    FlutterPlugin {
        key: "appsflyer",
        package_name: "segment_analytics_plugin_appsflyer",
        min_version: "1.0.2",
        import_name: "plugin_appsflyer",
        class_name: "AppsFlyerDestination",
    },
];

fn capitalize(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().to_string() + c.as_str(),
    }
}

fn resolve_flutter_plugins(requested: &[String]) -> Result<Vec<&'static FlutterPlugin>, String> {
    let mut resolved = Vec::new();
    for name in requested {
        let lower = name.to_lowercase();
        match FLUTTER_PLUGIN_REGISTRY.iter().find(|p| p.key == lower) {
            Some(p) => resolved.push(p),
            None => {
                let available: Vec<_> = FLUTTER_PLUGIN_REGISTRY.iter().map(|p| p.key).collect();
                return Err(format!(
                    "Unknown Flutter plugin '{name}'. Available: {}",
                    available.join(", ")
                ));
            }
        }
    }
    resolved.dedup_by_key(|p| p.key);
    Ok(resolved)
}

fn is_valid_dart_package_name(name: &str) -> bool {
    if name.is_empty() {
        return false;
    }
    let mut chars = name.chars();
    match chars.next() {
        Some(c) if c.is_ascii_lowercase() || c == '_' => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_')
}

fn prompt_flutter_plugins(already_selected: &[String]) -> Vec<String> {
    if !io::stdin().is_terminal() {
        return already_selected.to_vec();
    }

    let mut selected: Vec<bool> = FLUTTER_PLUGIN_REGISTRY
        .iter()
        .map(|p| already_selected.iter().any(|s| s.to_lowercase() == p.key))
        .collect();

    loop {
        eprintln!();
        eprintln!("Select destination plugins (enter numbers to toggle, Enter to confirm):");
        for (i, plugin) in FLUTTER_PLUGIN_REGISTRY.iter().enumerate() {
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
                if n >= 1 && n <= FLUTTER_PLUGIN_REGISTRY.len() {
                    selected[n - 1] = !selected[n - 1];
                }
            }
        }
    }

    FLUTTER_PLUGIN_REGISTRY
        .iter()
        .enumerate()
        .filter(|(i, _)| selected[*i])
        .map(|(_, p)| p.key.to_string())
        .collect()
}

fn ensure_flutter() -> bool {
    if which::which("flutter").is_ok() {
        return true;
    }
    err("flutter not found in PATH. Install Flutter from https://docs.flutter.dev/get-started/install and ensure it is on your PATH.");
    false
}

fn generate_flutter_pubspec(name: &str, _org: &str, plugins: &[&FlutterPlugin]) -> String {
    let mut deps = String::from("  segment_analytics: ^1.1.11\n");
    for p in plugins {
        deps.push_str(&format!("  {}: ^{}\n", p.package_name, p.min_version));
    }
    format!(
        r#"name: {name}
description: A Flutter demo app with Segment Analytics.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
{deps}
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
"#,
        name = name,
        deps = deps,
    )
}

fn generate_flutter_main_dart(_name: &str, write_key: &str, plugins: &[&FlutterPlugin]) -> String {
    let mut plugin_imports = String::new();
    for p in plugins {
        plugin_imports.push_str(&format!(
            "import 'package:{}/{}.dart';\n",
            p.package_name, p.import_name
        ));
    }

    let mut plugin_adds = String::new();
    for p in plugins {
        plugin_adds.push_str(&format!("  analytics.addPlugin({}());\n", p.class_name));
    }

    let mut toggle_states = String::new();
    for p in plugins {
        toggle_states.push_str(&format!(
            "  bool _{key}Enabled = false;\n  Plugin? _{key}Plugin;\n",
            key = p.key
        ));
    }

    let mut plugin_rows = String::new();
    for p in plugins {
        let display = capitalize(p.key);
        plugin_rows.push_str(&format!(
            r#"              _PluginRow(
                name: '{display}',
                enabled: _{key}Enabled,
                onChanged: (v) {{
                  setState(() => _{key}Enabled = v);
                  if (v) {{
                    _{key}Plugin = {constructor}();
                    analytics.addPlugin(_{key}Plugin!);
                    debugPrint('{display} destination enabled');
                  }} else {{
                    if (_{key}Plugin != null) {{
                      analytics.removePlugin(_{key}Plugin!);
                      _{key}Plugin = null;
                    }}
                    debugPrint('{display} destination disabled');
                  }}
                }},
              ),
"#,
            key = p.key,
            display = display,
            constructor = p.class_name,
        ));
    }

    let toggle_section = if plugins.is_empty() {
        String::new()
    } else {
        format!(
            r#"
              const Divider(),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Destination Plugins',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
{plugin_rows}"#,
            plugin_rows = plugin_rows,
        )
    };

    let debug_flag = if write_key == "demo_write_key_not_real" { "debug: true" } else { "debug: false" };

    format!(
        r#"import 'package:flutter/material.dart';
import 'package:segment_analytics/analytics.dart';
import 'package:segment_analytics/client.dart';
import 'package:segment_analytics/state.dart';
import 'config.dart';
import 'console_logger_plugin.dart';
{plugin_imports}
late Analytics analytics;

void main() {{
  WidgetsFlutterBinding.ensureInitialized();

  analytics = createClient(Configuration(Config.segmentWriteKey, {debug_flag}));
  analytics.addPlugin(ConsoleLoggerPlugin());
{plugin_adds}
  debugPrint('Segment Analytics initialized');
  debugPrint('  Write Key: ${{Config.segmentWriteKey}}');
  debugPrint('  Mode: ${{Config.isUsingDemoKey ? "Demo (events queued locally)" : "Live (sending to Segment)"}}');

  runApp(const MyApp());
}}

class MyApp extends StatelessWidget {{
  const MyApp({{super.key}});

  @override
  Widget build(BuildContext context) {{
    return MaterialApp(
      title: 'Segment Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }}
}}

class HomePage extends StatefulWidget {{
  const HomePage({{super.key}});

  @override
  State<HomePage> createState() => _HomePageState();
}}

class _HomePageState extends State<HomePage> {{
  int _tracked = 0;
  int _inQueue = 0;
  int _sent = 0;
  bool _isManualFlush = false;
{toggle_states}
  void _record() {{
    setState(() {{
      _tracked++;
      if (_isManualFlush) {{
        _inQueue++;
      }} else {{
        _sent++;
      }}
    }});
  }}

  void _flush() {{
    analytics.flush();
    setState(() {{
      _sent += _inQueue;
      _inQueue = 0;
    }});
  }}

  void _trackEvent() {{
    _record();
    analytics.track('Button Pressed', properties: {{
      'button': 'Track Event',
      'count': _tracked,
      'timestamp': DateTime.now().toIso8601String(),
    }});
  }}

  void _identifyUser() {{
    _record();
    analytics.identify(userId: 'demo-user');
  }}

  void _trackScreen() {{
    _record();
    analytics.screen('Demo Screen', properties: {{
      'screen_name': 'HomePage',
      'view_count': _tracked,
    }});
  }}

  @override
  Widget build(BuildContext context) {{
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.show_chart, size: 60, color: Colors.blue),
              const SizedBox(height: 8),
              const Text(
                'Segment Flutter Demo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Analytics Flutter SDK',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (Config.isUsingDemoKey)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Demo mode',
                        style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {{}}),
                      child: Text(
                        'Recheck',
                        style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),
              Row(children: [
                _StatCard(value: _tracked, label: 'Tracked', color: Colors.blue),
                const SizedBox(width: 12),
                _StatCard(value: _inQueue, label: 'In Queue', color: Colors.orange),
                const SizedBox(width: 12),
                _StatCard(value: _sent, label: 'Sent', color: Colors.green),
              ]),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _trackEvent,
                icon: const Icon(Icons.bar_chart),
                label: const Text('Track Event'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _identifyUser,
                icon: const Icon(Icons.person),
                label: const Text('Identify User'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _trackScreen,
                icon: const Icon(Icons.phone_iphone),
                label: const Text('Track Screen'),
                style: FilledButton.styleFrom(backgroundColor: Colors.purple),
              ),
              const SizedBox(height: 24),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Flush Mode',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Auto')),
                      ButtonSegment(value: true, label: Text('Manual')),
                    ],
                    selected: {{_isManualFlush}},
                    onSelectionChanged: (s) => setState(() => _isManualFlush = s.first),
                  ),
                ],
              ),
              if (_isManualFlush) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _inQueue > 0 ? _flush : null,
                  icon: const Icon(Icons.upload),
                  label: Text('Flush Now ($_inQueue queued)'),
                ),
              ],
{toggle_section}
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }}
}}

class _PluginRow extends StatelessWidget {{
  final String name;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PluginRow({{required this.name, required this.enabled, required this.onChanged}});

  @override
  Widget build(BuildContext context) {{
    return InkWell(
      onTap: () => onChanged(!enabled),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(
            enabled ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: enabled ? Colors.blue : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 15))),
          Text(
            'Available',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ]),
      ),
    );
  }}
}}

class _StatCard extends StatelessWidget {{
  final int value;
  final String label;
  final Color color;

  const _StatCard({{required this.value, required this.label, required this.color}});

  @override
  Widget build(BuildContext context) {{
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }}
}}
"#,
        plugin_imports = plugin_imports,
        plugin_adds = plugin_adds,
        toggle_states = toggle_states,
        debug_flag = debug_flag,
        toggle_section = toggle_section,
    )
}

fn flutter_config_dart(write_key: &str) -> String {
    format!(
        r#"class Config {{
  static const segmentWriteKey = '{write_key}';

  static bool get isUsingDemoKey =>
      segmentWriteKey.isEmpty ||
      segmentWriteKey == 'demo_write_key_not_real' ||
      segmentWriteKey == 'YOUR_WRITE_KEY_HERE';
}}
"#,
        write_key = write_key,
    )
}

const FLUTTER_CONSOLE_LOGGER_DART: &str = r#"import 'package:flutter/foundation.dart';
import 'package:segment_analytics/event.dart';
import 'package:segment_analytics/plugin.dart';

class ConsoleLoggerPlugin extends Plugin {
  ConsoleLoggerPlugin() : super(PluginType.enrichment);

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    final typeName = event.type.toString().split('.').last.toUpperCase();
    final name = event is TrackEvent ? ' (${event.event})' : '';
    debugPrint('[Segment] $typeName$name');
    return event;
  }
}
"#;

fn generate_flutter_analysis_options() -> &'static str {
    r#"include: package:flutter_lints/flutter.yaml
"#
}

fn generate_flutter_gitignore() -> &'static str {
    r#"# Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
build/
*.iml

# Devbox
.devbox/
"#
}

fn generate_flutter_devbox_json(name: &str) -> String {
    format!(
        r#"{{
  "include": [
    "github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main",
    "github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"
  ],
  "packages": {{
    "process-compose": "latest"
  }},
  "env": {{
    "ANDROID_APP_APK": "build/app/outputs/flutter-apk/app-debug.apk",
    "IOS_APP_ARTIFACT": "build/ios/iphonesimulator/{name}.app"
  }},
  "shell": {{
    "scripts": {{
      "build:android": [
        "flutter build apk --debug"
      ],
      "build:ios": [
        "flutter build ios --debug --simulator"
      ],
      "start:emu": [
        "android.sh emulator start ${{1:-}}"
      ],
      "start:sim": [
        "ios.sh simulator start ${{1:-}}"
      ],
      "start:app:android": [
        "android.sh deploy && flutter run --no-pub"
      ],
      "start:app:ios": [
        "ios.sh run ${{1:-}}"
      ],
      "stop:emu": [
        "android.sh emulator stop"
      ],
      "stop:sim": [
        "ios.sh simulator stop"
      ],
      "test": [
        "flutter test"
      ]
    }}
  }}
}}
"#,
        name = name
    )
}

fn patch_android_ndk(out: &PathBuf) {
    let gradle_path = out.join("android/app/build.gradle.kts");
    let Ok(content) = std::fs::read_to_string(&gradle_path) else {
        return;
    };
    let patched = content.replace(
        "ndkVersion = flutter.ndkVersion",
        "ndkVersion = \"27.0.12077973\"",
    );
    if patched != content {
        std::fs::write(&gradle_path, patched).ok();
    }
}

fn init_flutter(
    name: String,
    org: String,
    write_key: String,
    plugin_names: Vec<String>,
    needs_wizard: bool,
) -> ExitCode {
    if !is_valid_dart_package_name(&name) {
        err(&format!(
            "Project name '{name}' is not a valid Dart package name. \
             Use only lowercase letters, digits, and underscores (e.g. segment_demo, my_app)."
        ));
        return ExitCode::FAILURE;
    }

    let plugin_names = if needs_wizard && plugin_names.is_empty() {
        prompt_flutter_plugins(&plugin_names)
    } else {
        plugin_names
    };

    let plugins = match resolve_flutter_plugins(&plugin_names) {
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

    let out = PathBuf::from(&name);
    if out.exists() {
        err(&format!("Directory '{}' already exists.", out.display()));
        return ExitCode::FAILURE;
    }

    if !ensure_flutter() {
        return ExitCode::FAILURE;
    }

    info(&format!("Creating {name} from flutter template..."));

    let status = Command::new("flutter")
        .args(["create", "--org", &org, "--project-name", &name, "--platforms", "android,ios", &name])
        .status();

    match status {
        Ok(s) if s.success() => {}
        Ok(s) => {
            err(&format!("flutter create exited with code {}", s.code().unwrap_or(-1)));
            return ExitCode::FAILURE;
        }
        Err(e) => {
            err(&format!("Failed to run flutter create: {e}"));
            return ExitCode::FAILURE;
        }
    }

    write_file(&out, "pubspec.yaml", &generate_flutter_pubspec(&name, &org, &plugins));
    patch_android_ndk(&out);
    write_file(&out, "lib/main.dart", &generate_flutter_main_dart(&name, &write_key, &plugins));
    write_file(&out, "lib/config.dart", &flutter_config_dart(&write_key));
    write_file(&out, "lib/console_logger_plugin.dart", FLUTTER_CONSOLE_LOGGER_DART);
    write_file(&out, "analysis_options.yaml", generate_flutter_analysis_options());
    write_file(&out, ".gitignore", generate_flutter_gitignore());
    write_file(&out, "devbox.json", &generate_flutter_devbox_json(&name));
    write_file(&out, "devbox.d/android/devices/max.json", FLUTTER_ANDROID_DEVICE_MAX_JSON);
    write_file(&out, "devbox.d/android/devices/min.json", FLUTTER_ANDROID_DEVICE_MIN_JSON);
    write_file(&out, "devbox.d/ios/devices/max.json", DEVICE_MAX_JSON);
    write_file(&out, "devbox.d/ios/devices/min.json", DEVICE_MIN_JSON);

    info("Running doctor --fix to ensure dependencies are installed...");
    let doctor_result = doctor::run(true);
    if doctor_result != ExitCode::SUCCESS {
        err("doctor --fix reported issues; the project was still created.");
    }

    info("Done!");
    eprintln!();
    eprintln!("  cd {name}");
    eprintln!("  devbox shell");
    eprintln!("  devbox run build:android   # or build:ios");
    eprintln!("  devbox run start:emu       # start Android emulator");
    eprintln!("  devbox run start:app:android");
    eprintln!();

    ExitCode::SUCCESS
}

const FLUTTER_ANDROID_DEVICE_MAX_JSON: &str = r#"{
  "name": "pixel_9",
  "api": 36,
  "device": "pixel_9",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
"#;

const FLUTTER_ANDROID_DEVICE_MIN_JSON: &str = r#"{
  "name": "pixel_6",
  "api": 28,
  "device": "pixel_6",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
"#;
