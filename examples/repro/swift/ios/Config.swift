//
//  Config.swift
//  ios
//
//  Demo configuration - events are queued but not sent (flushAt disabled)
//

import Foundation

enum Config {
    /// Demo write key - events are queued locally but not sent to Segment
    /// To send real events, replace with your write key from https://app.segment.com
    /// Get your write key: Sources → Your iOS Source → Settings → API Keys
    static let segmentWriteKey = "demo_write_key_not_real"
}
