//
//  ContentView.swift
//  ios
//
//  Segment iOS SDK Demo App
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
        // Initialize Segment Analytics
        let configuration = Configuration(writeKey: Config.segmentWriteKey)
            .flushInterval(10)

        self.analytics = Analytics(configuration: configuration)

        // Add ConsoleLogger plugin for debugging
        analytics.add(plugin: ConsoleLoggerPlugin())

        print("🚀 Segment Analytics initialized")
        print("   Write Key: \(Config.segmentWriteKey)")
        print("   Plugins: ConsoleLogger, Amplitude")
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Segment iOS Demo")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Analytics Swift SDK v1.6.2+")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            Spacer()

            // Event counter
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

            // Action buttons
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

            // Amplitude toggle
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
        .onAppear {
            print("\n🎯 App appeared - ready to track events")
            print("   Amplitude destination: \(amplitudeEnabled ? "enabled" : "disabled")")
        }
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
            print("✅ Amplitude destination enabled")
        } else {
            // Note: Removing plugins requires accessing analytics.timeline
            // For now, just log the action
            print("❌ Amplitude destination disabled (plugin removal requires timeline access)")
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
