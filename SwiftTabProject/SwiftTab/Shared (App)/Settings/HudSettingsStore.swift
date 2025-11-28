#if os(macOS)
import Foundation

final class HudSettingsStore {
    static let shared = HudSettingsStore()

    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = UserDefaults(suiteName: HudSettingsDefaults.groupIdentifier) ?? .standard) {
        defaults = userDefaults
    }

    private func clampDelay(_ value: Int) -> Int {
        if value < 0 { return 0 }
        if value > 1000 { return 1000 }
        return value
    }

    private func readShortcut(forKey key: String, fallback: ShortcutSetting) -> ShortcutSetting {
        let stored = defaults.object(forKey: key)
        return ShortcutSetting.fromStorage(stored, fallback: fallback)
    }

    private func persistShortcut(_ shortcut: ShortcutSetting, forKey key: String, fallback: ShortcutSetting) {
        let normalized = shortcut.normalized(fallback: fallback)
        defaults.set(normalized.storageValue, forKey: key)
    }

    private func readSearchWeights(forKey key: String, fallback: SearchWeights) -> SearchWeights {
        let stored = defaults.object(forKey: key)
        return SearchWeights.fromStorage(stored, fallback: fallback)
    }

    private func persistSearchWeights(_ weights: SearchWeights, forKey key: String, fallback: SearchWeights) {
        defaults.set(weights.storageValue, forKey: key)
    }

    private func loadSnapshot(log: Bool) -> (HudSettingsState, TimeInterval) {
        let updatedAt = defaults.object(forKey: HudSettingsDefaults.storageUpdatedAtKey) as? TimeInterval ?? 0
        let enabled = defaults.object(forKey: HudSettingsDefaults.enabledKey) as? Bool
            ?? HudSettingsDefaults.defaults.enabled
        let delay = defaults.object(forKey: HudSettingsDefaults.delayKey) as? Int
            ?? HudSettingsDefaults.defaults.hudDelay
        let layout = HudLayoutMode(rawValue: defaults.string(forKey: HudSettingsDefaults.layoutKey) ?? "")
            ?? HudSettingsDefaults.defaults.layout
        let theme = HudThemeMode(rawValue: defaults.string(forKey: HudSettingsDefaults.themeKey) ?? "")
            ?? HudSettingsDefaults.defaults.theme
        let goToLastTabOnClose = defaults.object(forKey: HudSettingsDefaults.goToLastTabOnCloseKey) as? Bool
            ?? HudSettingsDefaults.defaults.goToLastTabOnClose
        let switchShortcut = readShortcut(
            forKey: HudSettingsDefaults.switchShortcutKey,
            fallback: HudSettingsDefaults.defaultSwitchShortcut
        )
        let searchShortcut = readShortcut(
            forKey: HudSettingsDefaults.searchShortcutKey,
            fallback: HudSettingsDefaults.defaultSearchShortcut
        )
        let searchWeights = readSearchWeights(
            forKey: HudSettingsDefaults.searchWeightsKey,
            fallback: HudSettingsDefaults.defaultSearchWeights
        )

        let snapshot = HudSettingsState(
            enabled: enabled,
            hudDelay: clampDelay(delay),
            layout: layout,
            theme: theme,
            goToLastTabOnClose: goToLastTabOnClose,
            switchShortcut: switchShortcut,
            searchShortcut: searchShortcut,
            searchWeights: searchWeights
        )

        if log {
            if updatedAt > 0 {
                print("[SwiftTab][Settings] Loaded settings from defaults (updatedAt=\(updatedAt), layout=\(layout.rawValue), theme=\(theme.rawValue))")
            } else {
                print("[SwiftTab][Settings] Loaded settings from defaults (no timestamp, layout=\(layout.rawValue), theme=\(theme.rawValue))")
            }
        }

        return (snapshot, updatedAt)
    }

    func load() -> HudSettingsState {
        let (snapshot, _) = loadSnapshot(log: true)
        return snapshot
    }

    func save(_ settings: HudSettingsState) {
        let validation = validateShortcuts(switchShortcut: settings.switchShortcut, searchShortcut: settings.searchShortcut)
        guard validation.errors.isEmpty else { return }

        let next = HudSettingsState(
            enabled: settings.enabled,
            hudDelay: clampDelay(settings.hudDelay),
            layout: settings.layout,
            theme: settings.theme,
            goToLastTabOnClose: settings.goToLastTabOnClose,
            switchShortcut: settings.switchShortcut,
            searchShortcut: settings.searchShortcut,
            searchWeights: settings.searchWeights
        )

        let (current, _) = loadSnapshot(log: false)
        guard current != next else { return }

        defaults.set(next.enabled, forKey: HudSettingsDefaults.enabledKey)
        defaults.set(next.hudDelay, forKey: HudSettingsDefaults.delayKey)
        defaults.set(next.layout.rawValue, forKey: HudSettingsDefaults.layoutKey)
        defaults.set(next.theme.rawValue, forKey: HudSettingsDefaults.themeKey)
        defaults.set(next.goToLastTabOnClose, forKey: HudSettingsDefaults.goToLastTabOnCloseKey)
        persistShortcut(
            next.switchShortcut,
            forKey: HudSettingsDefaults.switchShortcutKey,
            fallback: HudSettingsDefaults.defaultSwitchShortcut
        )
        persistShortcut(
            next.searchShortcut,
            forKey: HudSettingsDefaults.searchShortcutKey,
            fallback: HudSettingsDefaults.defaultSearchShortcut
        )
        persistSearchWeights(
            next.searchWeights,
            forKey: HudSettingsDefaults.searchWeightsKey,
            fallback: HudSettingsDefaults.defaultSearchWeights
        )
        let timestamp = Date().timeIntervalSince1970
        defaults.set(timestamp, forKey: HudSettingsDefaults.storageUpdatedAtKey)
        defaults.synchronize()
        print("[SwiftTab][Settings] Saved settings to defaults (updatedAt=\(timestamp), layout=\(next.layout.rawValue), theme=\(next.theme.rawValue), delay=\(next.hudDelay))")
        DistributedNotificationCenter.default().post(name: HudSettingsDefaults.changedNotification, object: nil)
    }
}
#endif
