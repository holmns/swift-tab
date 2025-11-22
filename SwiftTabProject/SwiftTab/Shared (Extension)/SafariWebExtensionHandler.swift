//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Updated to sync HUD settings between the Safari extension and the macOS app.
//

import SafariServices
import Foundation

private enum NativeMessageType: String {
    case readSettings = "read-settings"
    case writeSettings = "write-settings"
    case subscribeSettings = "subscribe-settings"
}

private enum NativeSettingsKeys {
    static let groupIdentifier = "group.com.holmns.swifttab"
    static let enabledKey = "swiftTab.hudSettings.enabled"
    static let delayKey = "swiftTab.hudSettings.hudDelay"
    static let layoutKey = "swiftTab.hudSettings.layout"
    static let themeKey = "swiftTab.hudSettings.theme"
    static let updatedKey = "swiftTab.hudSettings.updatedAt"
    static let changedNotification = Notification.Name("com.holmns.swifttab.settingsChanged")
}

private struct NativeHudSettings {
    var enabled: Bool
    var hudDelay: Int
    var layout: String
    var theme: String
}

private final class NativeSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: NativeSettingsKeys.groupIdentifier) ?? .standard) {
        self.defaults = defaults
    }

    private func clampDelay(_ value: Int) -> Int {
        if value < 0 { return 0 }
        if value > 1000 { return 1000 }
        return value
    }

    func load() -> NativeHudSettings {
        let enabled = defaults.object(forKey: NativeSettingsKeys.enabledKey) as? Bool ?? true
        let hudDelay = defaults.object(forKey: NativeSettingsKeys.delayKey) as? Int ?? 100
        let layout = defaults.string(forKey: NativeSettingsKeys.layoutKey) ?? "vertical"
        let theme = defaults.string(forKey: NativeSettingsKeys.themeKey) ?? "system"

        return NativeHudSettings(
            enabled: enabled,
            hudDelay: clampDelay(hudDelay),
            layout: layout,
            theme: theme
        )
    }

    func save(_ settings: NativeHudSettings) {
        defaults.set(settings.enabled, forKey: NativeSettingsKeys.enabledKey)
        defaults.set(clampDelay(settings.hudDelay), forKey: NativeSettingsKeys.delayKey)
        defaults.set(settings.layout, forKey: NativeSettingsKeys.layoutKey)
        defaults.set(settings.theme, forKey: NativeSettingsKeys.themeKey)
        defaults.set(Date().timeIntervalSince1970, forKey: NativeSettingsKeys.updatedKey)
        defaults.synchronize()
        DistributedNotificationCenter.default().post(name: NativeSettingsKeys.changedNotification, object: nil)
    }

    var updatedAt: Double {
        defaults.double(forKey: NativeSettingsKeys.updatedKey)
    }
}

private struct PendingSubscription {
    weak var context: NSExtensionContext?
    let timeout: DispatchWorkItem
}

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let settingsStore = NativeSettingsStore()
    private var pendingSubscriptions: [PendingSubscription] = []
    private let subscriptionTimeout: TimeInterval = 25

    override init() {
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleExternalSettingsChange),
            name: NativeSettingsKeys.changedNotification,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func beginRequest(with context: NSExtensionContext) {
        guard let request = context.inputItems.first as? NSExtensionItem else {
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        let rawMessage: Any?
        if #available(macOS 11.0, *) {
            rawMessage = request.userInfo?[SFExtensionMessageKey]
        } else {
            rawMessage = request.userInfo?["message"]
        }

        guard
            let message = rawMessage as? [String: Any],
            let typeRaw = message["type"] as? String,
            let messageType = NativeMessageType(rawValue: typeRaw)
        else {
            respond(context, payload: ["type": "error", "reason": "invalid-message"])
            return
        }

        switch messageType {
        case .readSettings:
            respond(context, payload: settingsPayload(type: "settings"))
        case .writeSettings:
            let incoming = message["settings"] as? [String: Any] ?? [:]
            let current = settingsStore.load()
            let parsedDelay: Int = {
                if let number = incoming["hudDelay"] as? NSNumber {
                    return number.intValue
                }
                return incoming["hudDelay"] as? Int ?? current.hudDelay
            }()
            let merged = NativeHudSettings(
                enabled: incoming["enabled"] as? Bool ?? current.enabled,
                hudDelay: parsedDelay,
                layout: incoming["layout"] as? String ?? current.layout,
                theme: incoming["theme"] as? String ?? current.theme
            )
            settingsStore.save(merged)
            respond(context, payload: settingsPayload(type: "settings"))
            notifySubscribers(excluding: context)
        case .subscribeSettings:
            addSubscription(for: context)
        }
    }

    @objc
    private func handleExternalSettingsChange() {
        notifySubscribers()
    }
}

private extension SafariWebExtensionHandler {
    func settingsPayload(type: String) -> [String: Any] {
        let settings = settingsStore.load()
        return [
            "type": type,
            "settings": [
                "enabled": settings.enabled,
                "hudDelay": settings.hudDelay,
                "layout": settings.layout,
                "theme": settings.theme
            ],
            "updatedAt": settingsStore.updatedAt
        ]
    }

    func respond(_ context: NSExtensionContext, payload: [String: Any]) {
        let response = NSExtensionItem()
        if #available(macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: payload]
        } else {
            response.userInfo = ["message": payload]
        }
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    func addSubscription(for context: NSExtensionContext) {
        pendingSubscriptions = pendingSubscriptions.filter { $0.context != nil }
        let timeout = DispatchWorkItem { [weak self, weak context] in
            guard let context else { return }
            self?.respond(context, payload: self?.settingsPayload(type: "settings-update") ?? [:])
            self?.pendingSubscriptions.removeAll { $0.context == nil || $0.context === context }
        }
        pendingSubscriptions.append(PendingSubscription(context: context, timeout: timeout))
        DispatchQueue.main.asyncAfter(deadline: .now() + subscriptionTimeout, execute: timeout)
    }

    func notifySubscribers(excluding context: NSExtensionContext? = nil) {
        let payload = settingsPayload(type: "settings-update")
        var remaining: [PendingSubscription] = []

        for subscription in pendingSubscriptions {
            guard let targetContext = subscription.context else { continue }
            if let exclusion = context, exclusion === targetContext {
                remaining.append(subscription)
                continue
            }

            subscription.timeout.cancel()
            respond(targetContext, payload: payload)
        }

        pendingSubscriptions = remaining
    }
}
