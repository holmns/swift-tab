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
    static let enabledKey = "swifttab.hudSettings.enabled"
    static let delayKey = "swifttab.hudSettings.hudDelay"
    static let layoutKey = "swifttab.hudSettings.layout"
    static let themeKey = "swifttab.hudSettings.theme"
    static let goToLastTabOnCloseKey = "swifttab.hudSettings.goToLastTabOnClose"
    static let closeShortcutKeyKey = "swifttab.hudSettings.closeShortcutKey"
    static let switchShortcutKey = "swifttab.hudSettings.switchShortcut"
    static let searchShortcutKey = "swifttab.hudSettings.searchShortcut"
    static let searchWeightsKey = "swifttab.hudSettings.searchWeights"
    static let updatedKey = "swifttab.hudSettings.updatedAt"
    static let changedNotification = Notification.Name("com.holmns.swifttab.settingsChanged")
}

private enum NativeDefaults {
    static let switchShortcut = NativeShortcutSetting(key: "tab", alt: true, ctrl: false, meta: false, shift: false)
    static let searchShortcut = NativeShortcutSetting(key: "space", alt: true, ctrl: false, meta: false, shift: false)
    static let closeShortcutKey = "w"
    static let searchWeights = NativeSearchWeights(title: 3, hostname: 5, url: 1)
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

private struct NativeSearchWeights: Equatable {
    var title: Int
    var hostname: Int
    var url: Int

    func clamped(min: Int = 0, max: Int = 10) -> NativeSearchWeights {
        NativeSearchWeights(
            title: Swift.max(min, Swift.min(max, title)),
            hostname: Swift.max(min, Swift.min(max, hostname)),
            url: Swift.max(min, Swift.min(max, url))
        )
    }

    var dictionary: [String: Any] {
        [
            "title": title,
            "hostname": hostname,
            "url": url
        ]
    }

    static func parse(_ raw: Any?, fallback: NativeSearchWeights) -> NativeSearchWeights {
        guard let dict = raw as? [String: Any] else { return fallback }
        let title = dict["title"] as? Int ?? fallback.title
        let hostname = dict["hostname"] as? Int ?? fallback.hostname
        let url = dict["url"] as? Int ?? fallback.url
        return NativeSearchWeights(title: title, hostname: hostname, url: url).clamped()
    }
}

private func normalizeShortcutKeyValue(_ raw: Any?, fallback: String) -> String {
    guard let string = raw as? String else { return fallback }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return fallback }
    let lower = trimmed.lowercased()
    if lower == "spacebar" || lower == " " { return "space" }
    if lower == "\t" || lower == "tab" { return "tab" }
    return lower
}

private func resolveCloseShortcutKey(
    _ closeKey: String,
    switchShortcut: NativeShortcutSetting,
    searchShortcut: NativeShortcutSetting,
    fallback: String
) -> String {
    let candidates = [
        normalizeShortcutKeyValue(closeKey, fallback: fallback),
        fallback,
        NativeDefaults.closeShortcutKey,
        "delete",
        "backspace"
    ]
    for candidate in candidates {
        let normalized = normalizeShortcutKeyValue(candidate, fallback: fallback)
        if normalized == switchShortcut.normalizedKey || normalized == searchShortcut.normalizedKey {
            continue
        }
        return normalized
    }
    return NativeDefaults.closeShortcutKey
}

private struct NativeHudSettings {
    var enabled: Bool
    var hudDelay: Int
    var layout: String
    var theme: String
    var goToLastTabOnClose: Bool
    var closeShortcutKey: String
    var switchShortcut: NativeShortcutSetting
    var searchShortcut: NativeShortcutSetting
    var searchWeights: NativeSearchWeights
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
        let closeShortcutKey = resolveCloseShortcutKey(
            defaults.string(forKey: NativeSettingsKeys.closeShortcutKeyKey) ?? NativeDefaults.closeShortcutKey,
            switchShortcut: switchShortcut,
            searchShortcut: searchShortcut,
            fallback: NativeDefaults.closeShortcutKey
        )
        let searchWeights = NativeSearchWeights.parse(
            defaults.object(forKey: NativeSettingsKeys.searchWeightsKey),
            fallback: NativeDefaults.searchWeights
        )

        return NativeHudSettings(
            enabled: enabled,
            hudDelay: clampDelay(hudDelay),
            layout: layout,
            theme: theme,
            goToLastTabOnClose: goToLastTabOnClose,
            closeShortcutKey: closeShortcutKey,
            switchShortcut: switchShortcut,
            searchShortcut: searchShortcut,
            searchWeights: searchWeights
        )
    }

    func save(_ settings: NativeHudSettings) {
        guard settings.switchShortcut != settings.searchShortcut else { return }
        let resolvedCloseKey = resolveCloseShortcutKey(
            settings.closeShortcutKey,
            switchShortcut: settings.switchShortcut,
            searchShortcut: settings.searchShortcut,
            fallback: NativeDefaults.closeShortcutKey
        )
        defaults.set(settings.enabled, forKey: NativeSettingsKeys.enabledKey)
        defaults.set(clampDelay(settings.hudDelay), forKey: NativeSettingsKeys.delayKey)
        defaults.set(settings.layout, forKey: NativeSettingsKeys.layoutKey)
        defaults.set(settings.theme, forKey: NativeSettingsKeys.themeKey)
        defaults.set(settings.goToLastTabOnClose, forKey: NativeSettingsKeys.goToLastTabOnCloseKey)
        defaults.set(
            normalizeShortcutKeyValue(
                resolvedCloseKey,
                fallback: NativeDefaults.closeShortcutKey
            ),
            forKey: NativeSettingsKeys.closeShortcutKeyKey
        )
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
        defaults.set(
            settings.searchWeights.clamped().dictionary,
            forKey: NativeSettingsKeys.searchWeightsKey
        )
        defaults.set(Date().timeIntervalSince1970, forKey: NativeSettingsKeys.updatedKey)
        defaults.synchronize()
        DistributedNotificationCenter.default().post(name: NativeSettingsKeys.changedNotification, object: nil)
    }

    var updatedAt: Double {
        defaults.double(forKey: NativeSettingsKeys.updatedKey)
    }
}

private func makeSettingsPayload(type: String, store: NativeSettingsStore) -> [String: Any] {
    let settings = store.load()
    return [
        "type": type,
        "settings": [
            "enabled": settings.enabled,
            "hudDelay": settings.hudDelay,
            "layout": settings.layout,
            "theme": settings.theme,
            "goToLastTabOnClose": settings.goToLastTabOnClose,
            "closeShortcutKey": settings.closeShortcutKey,
            "switchShortcut": settings.switchShortcut.dictionary,
            "searchShortcut": settings.searchShortcut.dictionary,
            "searchWeights": settings.searchWeights.dictionary
        ],
        "updatedAt": store.updatedAt
    ]
}

private func respond(_ context: NSExtensionContext, payload: [String: Any]) {
    let response = NSExtensionItem()
    if #available(macOS 11.0, *) {
        response.userInfo = [SFExtensionMessageKey: payload]
    } else {
        response.userInfo = ["message": payload]
    }
    context.completeRequest(returningItems: [response], completionHandler: nil)
}

/// Holds pending `subscribe-settings` requests across handler instances.
///
/// Safari may create a fresh `SafariWebExtensionHandler` for every message and
/// release it once `beginRequest` returns, so the subscription registry and the
/// distributed-notification observer must outlive any single handler. Contexts
/// are held strongly: a parked request must stay alive until we complete it.
private final class NativeSettingsBroadcaster: NSObject {
    static let shared = NativeSettingsBroadcaster()

    private struct Subscription {
        let id: UUID
        let context: NSExtensionContext
        let timeout: DispatchWorkItem
    }

    private let store = NativeSettingsStore()
    private let lock = NSLock()
    private var subscriptions: [Subscription] = []
    private let timeoutInterval: TimeInterval = 25

    private override init() {
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleExternalSettingsChange),
            name: NativeSettingsKeys.changedNotification,
            object: nil
        )
    }

    func addSubscription(for context: NSExtensionContext, since: Double) {
        // The client missed an update between long-polls; catch it up now
        // instead of parking the request.
        if since < store.updatedAt {
            respond(context, payload: makeSettingsPayload(type: "settings-update", store: store))
            return
        }

        let id = UUID()
        let timeout = DispatchWorkItem { [weak self] in
            self?.complete(ids: [id])
        }
        lock.lock()
        subscriptions.append(Subscription(id: id, context: context, timeout: timeout))
        lock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutInterval, execute: timeout)
    }

    func notifySubscribers() {
        lock.lock()
        let ids = subscriptions.map { $0.id }
        lock.unlock()
        complete(ids: ids)
    }

    @objc
    private func handleExternalSettingsChange() {
        notifySubscribers()
    }

    private func complete(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        lock.lock()
        let targets = subscriptions.filter { subscription in ids.contains(subscription.id) }
        subscriptions.removeAll { subscription in ids.contains(subscription.id) }
        lock.unlock()
        guard !targets.isEmpty else { return }

        let payload = makeSettingsPayload(type: "settings-update", store: store)
        for target in targets {
            target.timeout.cancel()
            respond(target.context, payload: payload)
        }
    }
}

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let settingsStore = NativeSettingsStore()

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
            respond(context, payload: makeSettingsPayload(type: "settings", store: settingsStore))
        case .writeSettings:
            let incoming = message["settings"] as? [String: Any] ?? [:]
            let current = settingsStore.load()
            let parsedDelay: Int = {
                if let number = incoming["hudDelay"] as? NSNumber {
                    return number.intValue
                }
                return incoming["hudDelay"] as? Int ?? current.hudDelay
            }()
            let incomingSwitchShortcut = NativeShortcutSetting.parse(
                incoming["switchShortcut"],
                fallback: current.switchShortcut
            )
            let incomingSearchShortcut = NativeShortcutSetting.parse(
                incoming["searchShortcut"],
                fallback: current.searchShortcut
            )
            let resolvedCloseKey = resolveCloseShortcutKey(
                normalizeShortcutKeyValue(
                    incoming["closeShortcutKey"],
                    fallback: current.closeShortcutKey
                ),
                switchShortcut: incomingSwitchShortcut,
                searchShortcut: incomingSearchShortcut,
                fallback: current.closeShortcutKey
            )
            let merged = NativeHudSettings(
                enabled: incoming["enabled"] as? Bool ?? current.enabled,
                hudDelay: parsedDelay,
                layout: incoming["layout"] as? String ?? current.layout,
                theme: incoming["theme"] as? String ?? current.theme,
                goToLastTabOnClose: incoming["goToLastTabOnClose"] as? Bool ?? current.goToLastTabOnClose,
                closeShortcutKey: resolvedCloseKey,
                switchShortcut: incomingSwitchShortcut,
                searchShortcut: incomingSearchShortcut,
                searchWeights: NativeSearchWeights.parse(
                    incoming["searchWeights"],
                    fallback: current.searchWeights
                )
            )
            settingsStore.save(merged)
            respond(context, payload: makeSettingsPayload(type: "settings", store: settingsStore))
            NativeSettingsBroadcaster.shared.notifySubscribers()
        case .subscribeSettings:
            let since = (message["since"] as? NSNumber)?.doubleValue ?? 0
            NativeSettingsBroadcaster.shared.addSubscription(for: context, since: since)
        case .openApp:
            let opened = launchContainerApp()
            respond(context, payload: ["type": "open-app", "ok": opened])
        }
    }
}

private extension SafariWebExtensionHandler {
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
}
