//
//  IDFAPlugin.swift
//  ios
//
//  Simple enrichment plugin that adds IDFA to events
//  Based on: https://github.com/segmentio/analytics-swift/blob/main/Examples/other_plugins/IDFACollection.swift
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

        // Wait for authorization if needed
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            if status == .notDetermined {
                return event
            }
        }

        // Get IDFA
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString

        // Add to context
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
