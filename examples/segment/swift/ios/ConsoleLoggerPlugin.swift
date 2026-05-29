//
//  ConsoleLoggerPlugin.swift
//  ios
//
//  Custom Segment plugin that logs all events to console
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
            print("📊 Track Event: \(trackEvent.event)")
            if let properties = trackEvent.properties {
                print("   Properties: \(properties)")
            }

        case let identifyEvent as IdentifyEvent:
            print("👤 Identify: \(identifyEvent.userId ?? "anonymous")")
            if let traits = identifyEvent.traits {
                print("   Traits: \(traits)")
            }

        case let screenEvent as ScreenEvent:
            print("📱 Screen: \(screenEvent.name ?? "Unknown")")
            if let properties = screenEvent.properties {
                print("   Properties: \(properties)")
            }

        case let groupEvent as GroupEvent:
            print("👥 Group: \(groupEvent.groupId)")
            if let traits = groupEvent.traits {
                print("   Traits: \(traits)")
            }

        case let aliasEvent as AliasEvent:
            print("🔗 Alias: \(aliasEvent.userId) → \(aliasEvent.previousId ?? "none")")

        default:
            print("📦 Event: \(Swift.type(of: event))")
        }

        return event
    }
}
