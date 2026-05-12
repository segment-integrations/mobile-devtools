use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

fn info(msg: &str) {
    eprintln!("\x1b[1;34m==> {}\x1b[0m", msg);
}

fn err(msg: &str) {
    eprintln!("\x1b[1;31m==> {}\x1b[0m", msg);
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

fn write_file(base: &Path, rel_path: &str, content: &str) {
    let path = base.join(rel_path);
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    fs::write(&path, content).unwrap_or_else(|e| {
        err(&format!("Failed to write {}: {e}", path.display()));
    });
}

fn apply(template: &str, name: &str, org: &str, write_key: &str, bundle_id: &str) -> String {
    template
        .replace("__NAME__", name)
        .replace("__ORG__", org)
        .replace("__WRITE_KEY__", write_key)
        .replace("__BUNDLE_ID__", bundle_id)
}

pub fn run(sdk: &str, name: &str, org: &str, write_key: &str) -> ExitCode {
    if sdk != "swift" {
        err(&format!("Unknown SDK: {sdk}. Only 'swift' is supported."));
        return ExitCode::FAILURE;
    }

    let bundle_id = format!("{org}.{name}");
    let out = PathBuf::from(name);

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

    // project.yml
    write_file(&out, "project.yml", &apply(PROJECT_YML, name, org, write_key, &bundle_id));

    // devbox.json
    write_file(&out, "devbox.json", &apply(DEVBOX_JSON, name, org, write_key, &bundle_id));

    // Device definitions
    write_file(&out, "devbox.d/ios/devices/max.json", DEVICE_MAX_JSON);
    write_file(&out, "devbox.d/ios/devices/min.json", DEVICE_MIN_JSON);

    // Swift source files
    let src = name;
    write_file(&out, &format!("{src}/Config.swift"), &apply(CONFIG_SWIFT, name, org, write_key, &bundle_id));
    write_file(&out, &format!("{src}/{name}App.swift"), &apply(APP_SWIFT, name, org, write_key, &bundle_id));
    write_file(&out, &format!("{src}/ContentView.swift"), &apply(CONTENT_VIEW_SWIFT, name, org, write_key, &bundle_id));
    write_file(&out, &format!("{src}/ConsoleLoggerPlugin.swift"), CONSOLE_LOGGER_SWIFT);
    write_file(&out, &format!("{src}/IDFAPlugin.swift"), IDFA_PLUGIN_SWIFT);

    // Asset catalogs
    write_file(&out, &format!("{src}/Assets.xcassets/Contents.json"), ASSETS_CONTENTS);
    write_file(&out, &format!("{src}/Assets.xcassets/AccentColor.colorset/Contents.json"), ACCENT_COLOR_CONTENTS);
    write_file(&out, &format!("{src}/Assets.xcassets/AppIcon.appiconset/Contents.json"), APP_ICON_CONTENTS);

    // Test files
    write_file(&out, &format!("{name}Tests/{name}Tests.swift"), &apply(TESTS_SWIFT, name, org, write_key, &bundle_id));
    write_file(&out, &format!("{name}UITests/{name}UITests.swift"), &apply(UI_TESTS_SWIFT, name, org, write_key, &bundle_id));
    write_file(&out, &format!("{name}UITests/{name}UITestsLaunchTests.swift"), &apply(UI_TESTS_LAUNCH_SWIFT, name, org, write_key, &bundle_id));

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

    info("Done!");
    eprintln!();
    eprintln!("  cd {name}");
    eprintln!("  devbox shell");
    eprintln!("  devbox run build");
    eprintln!("  devbox run start:app");
    eprintln!();

    ExitCode::SUCCESS
}

// ============================================================================
// Templates
// ============================================================================

const PROJECT_YML: &str = r#"name: __NAME__
options:
  bundleIdPrefix: __ORG__
  deploymentTarget:
    iOS: "16.0"
  generateEmptyDirectories: true
packages:
  Segment:
    url: https://github.com/segmentio/analytics-swift
    from: 1.9.3
  SegmentAmplitude:
    url: https://github.com/segment-integrations/analytics-swift-amplitude
    from: 1.5.0
targets:
  __NAME__:
    type: application
    platform: iOS
    sources: [__NAME__]
    dependencies:
      - package: Segment
      - package: SegmentAmplitude
    settings:
      GENERATE_INFOPLIST_FILE: YES
      INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
      INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: YES
      INFOPLIST_KEY_UILaunchScreen_Generation: YES
      INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
      INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
      SWIFT_EMIT_LOC_STRINGS: YES
  __NAME__Tests:
    type: bundle.unit-test
    platform: iOS
    sources: [__NAME__Tests]
    dependencies:
      - target: __NAME__
    settings:
      GENERATE_INFOPLIST_FILE: YES
  __NAME__UITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [__NAME__UITests]
    dependencies:
      - target: __NAME__
    settings:
      GENERATE_INFOPLIST_FILE: YES
"#;

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
    /// Segment write key
    /// Get yours at: https://app.segment.com -> Sources -> Your iOS Source -> Settings -> API Keys
    static let segmentWriteKey = "__WRITE_KEY__"

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

const CONTENT_VIEW_SWIFT: &str = r#"//
//  ContentView.swift
//  __NAME__
//

import SwiftUI
import Segment
import SegmentAmplitude

struct ContentView: View {
    @State private var eventCount = 0
    @State private var lastEventTime: Date?
    @State private var amplitudeEnabled = false

    let analytics: Analytics
    private let amplitudePlugin = AmplitudeSession()

    init() {
        var configuration = Configuration(writeKey: Config.segmentWriteKey)

        if Config.isUsingDemoKey {
            configuration = configuration
                .flushAt(1000)
                .flushInterval(0)
        } else {
            configuration = configuration
                .flushInterval(10)
        }

        self.analytics = Analytics(configuration: configuration)
        analytics.add(plugin: ConsoleLoggerPlugin())
        analytics.add(plugin: IDFAPlugin())

        print("Segment Analytics initialized")
        print("  Write Key: \(Config.segmentWriteKey)")
        print("  Mode: \(Config.isUsingDemoKey ? "Demo (events queued locally)" : "Live (sending to Segment)")")
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Segment iOS Demo")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Analytics Swift SDK")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            Spacer()

            VStack(spacing: 4) {
                Text("\(eventCount)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.blue)

                Text("Events Tracked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let lastTime = lastEventTime {
                    Text("Last: \(lastTime, formatter: dateFormatter)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.1))
            )

            Spacer()

            VStack(spacing: 16) {
                Button(action: trackEvent) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                        Text("Track Event")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }

                Button(action: identifyUser) {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Identify User")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }

                Button(action: trackScreen) {
                    HStack {
                        Image(systemName: "iphone")
                        Text("Track Screen")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.purple)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Divider()

                Toggle(isOn: $amplitudeEnabled) {
                    HStack {
                        Image(systemName: amplitudeEnabled ? "wave.3.right.circle.fill" : "wave.3.right.circle")
                            .foregroundStyle(amplitudeEnabled ? .blue : .gray)
                        Text("Amplitude Destination")
                            .font(.subheadline)
                    }
                }
                .onChange(of: amplitudeEnabled) { _, newValue in
                    toggleAmplitude(enabled: newValue)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }

    private func trackEvent() {
        eventCount += 1
        lastEventTime = Date()

        analytics.track(name: "Button Pressed", properties: [
            "button": "Track Event",
            "count": eventCount,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }

    private func identifyUser() {
        eventCount += 1
        lastEventTime = Date()

        analytics.identify(userId: "demo-user-\(UUID().uuidString.prefix(8))", traits: [
            "name": "Demo User",
            "email": "demo@example.com",
            "plan": "free",
            "event_count": eventCount
        ])
    }

    private func trackScreen() {
        eventCount += 1
        lastEventTime = Date()

        analytics.screen(title: "Demo Screen", properties: [
            "screen_name": "ContentView",
            "view_count": eventCount
        ])
    }

    private func toggleAmplitude(enabled: Bool) {
        if enabled {
            analytics.add(plugin: amplitudePlugin)
            print("Amplitude destination enabled")
        } else {
            print("Amplitude destination disabled")
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
}

#Preview {
    ContentView()
}
"#;

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
