//
//  Config.swift
//  ios
//
//  Demo configuration - replace write key to send real events
//

import Foundation

enum Config {
    /// Demo write key - replace with your real write key to send events to Segment
    /// Get your write key: https://app.segment.com → Sources → Your iOS Source → Settings → API Keys
    static let segmentWriteKey = "demo_write_key_not_real"

    /// Check if using demo/placeholder key
    static var isUsingDemoKey: Bool {
        segmentWriteKey.isEmpty ||
        segmentWriteKey == "demo_write_key_not_real" ||
        segmentWriteKey == "YOUR_WRITE_KEY_HERE"
    }
}
