//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Updated to sync HUD settings between the Safari extension and the macOS app.
//

import SafariServices
import Foundation
import AppKit

private enum NativeMessageType: String {
    case readSettings = "read-settings"
    case writeSettings = "write-settings"
    case subscribeSettings = "subscribe-settings"
    case openApp = "open-app"
}

private enum NativeSettingsKeys {
    static let groupIdentifier = "group.com.holmns.swifttab"
    static let enabledKey = "swiftTab.hudSettings.enabled"
    static let delayKey = "swiftTab.hudSettings.hudDelay"
    static let layoutKey = "swiftTab.hudSettings.layout"
    static let themeKey = "swiftTab.hudSettings.theme"
    static let goToLastTabOnCloseKey = "swiftTab.hudSettings.goToLastTabOnClose"
    static let switchShortcutKey = "swiftTab.hudSettings.switchShortcut"
    static let searchShortcutKey = "swiftTab.hudSettings.searchShortcut"
    static let updatedKey = "swiftTab.hudSettings.updatedAt"
    static let changedNotification = Notification.Name("com.holmns.swifttab.settingsChanged")
}

private enum NativeDefaults {
    static let switchShortcut = NativeShortcutSetting(key: "tab", alt: true, ctrl: false, meta: false, shift: false)
    static let searchShortcut = NativeShortcutSetting(key: "space", alt: true, ctrl: false, meta: false, shift: false)
}

private struct NativeShortcutSetting: Equatable {
    var key: String
    var alt: Bool
    var ctrl: Bool
    var meta: Bool
    var shift: Bool

    static func == (lhs: NativeShortcutSetting, rhs: NativeShortcutSetting) -> Bool {
        return lhs.key == rhs.key &&
            lhs.alt == rhs.alt &&
            lhs.ctrl == rhs.ctrl &&
            lhs.meta == rhs.meta &&
            lhs.shift == rhs.shift
    }

    var normalizedKey: String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "spacebar" || trimmed == " " { return "space" }
        if trimmed == "\t" { return "tab" }
        return trimmed
    }

    func normalized(fallback: NativeShortcutSetting) -> NativeShortcutSetting {
        let normalized = normalizedKey
        if normalized.isEmpty {
            return fallback
        }
        return NativeShortcutSetting(key: normalized, alt: alt, ctrl: ctrl, meta: meta, shift: shift)
    }

    var dictionary: [String: Any] {
        [
            "key": normalizedKey,
            "alt": alt,
            "ctrl": ctrl,
            "meta": meta,
            "shift": shift
        ]
    }

    static func parse(_ raw: Any?, fallback: NativeShortcutSetting) -> NativeShortcutSetting {
        guard let dict = raw as? [String: Any] else {
            return fallback
        }
        let key = dict["key"] as? String ?? fallback.key
        let alt = dict["alt"] as? Bool ?? fallback.alt
        let ctrl = dict["ctrl"] as? Bool ?? fallback.ctrl
        let meta = dict["meta"] as? Bool ?? fallback.meta
        let shift = dict["shift"] as? Bool ?? fallback.shift
        let parsed = NativeShortcutSetting(key: key, alt: alt, ctrl: ctrl, meta: meta, shift: shift)
        return parsed.normalized(fallback: fallback)
    }
}

private struct NativeHudSettings {
    var enabled: Bool
    var hudDelay: Int
    var layout: String
    var theme: String
    var goToLastTabOnClose: Bool
    var switchShortcut: NativeShortcutSetting
    var searchShortcut: NativeShortcutSetting
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
        let goToLastTabOnClose = defaults.object(forKey: NativeSettingsKeys.goToLastTabOnCloseKey) as? Bool ?? true
        let switchShortcut = NativeShortcutSetting.parse(
            defaults.object(forKey: NativeSettingsKeys.switchShortcutKey),
            fallback: NativeDefaults.switchShortcut
        )
        let searchShortcut = NativeShortcutSetting.parse(
            defaults.object(forKey: NativeSettingsKeys.searchShortcutKey),
            fallback: NativeDefaults.searchShortcut
        )

        return NativeHudSettings(
            enabled: enabled,
            hudDelay: clampDelay(hudDelay),
            layout: layout,
            theme: theme,
            goToLastTabOnClose: goToLastTabOnClose,
            switchShortcut: switchShortcut,
            searchShortcut: searchShortcut
        )
    }

    func save(_ settings: NativeHudSettings) {
        guard settings.switchShortcut != settings.searchShortcut else { return }
        defaults.set(settings.enabled, forKey: NativeSettingsKeys.enabledKey)
        defaults.set(clampDelay(settings.hudDelay), forKey: NativeSettingsKeys.delayKey)
        defaults.set(settings.layout, forKey: NativeSettingsKeys.layoutKey)
        defaults.set(settings.theme, forKey: NativeSettingsKeys.themeKey)
        defaults.set(settings.goToLastTabOnClose, forKey: NativeSettingsKeys.goToLastTabOnCloseKey)
        defaults.set(
            settings.switchShortcut.normalized(
                fallback: NativeDefaults.switchShortcut
            ).dictionary,
            forKey: NativeSettingsKeys.switchShortcutKey
        )
        defaults.set(
            settings.searchShortcut.normalized(
                fallback: NativeDefaults.searchShortcut
            ).dictionary,
            forKey: NativeSettingsKeys.searchShortcutKey
        )
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
                theme: incoming["theme"] as? String ?? current.theme,
                goToLastTabOnClose: incoming["goToLastTabOnClose"] as? Bool ?? current.goToLastTabOnClose,
                switchShortcut: NativeShortcutSetting.parse(
                    incoming["switchShortcut"],
                    fallback: current.switchShortcut
                ),
                searchShortcut: NativeShortcutSetting.parse(
                    incoming["searchShortcut"],
                    fallback: current.searchShortcut
                )
            )
            settingsStore.save(merged)
            respond(context, payload: settingsPayload(type: "settings"))
            notifySubscribers(excluding: context)
        case .subscribeSettings:
            addSubscription(for: context)
        case .openApp:
            let opened = launchContainerApp()
            respond(context, payload: ["type": "open-app", "ok": opened])
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
                "theme": settings.theme,
                "goToLastTabOnClose": settings.goToLastTabOnClose,
                "switchShortcut": settings.switchShortcut.dictionary,
                "searchShortcut": settings.searchShortcut.dictionary
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

    func launchContainerApp() -> Bool {
        let bundleIdentifiers = [
            "com.holmns.swifttab",
            "com.holmns.SwiftTab",
        ]

        for identifier in bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
                return true
            }
        }
        return false
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
