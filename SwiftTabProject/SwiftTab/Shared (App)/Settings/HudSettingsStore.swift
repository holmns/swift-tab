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

    func load() -> HudSettingsState {
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

        return HudSettingsState(
            enabled: enabled,
            hudDelay: clampDelay(delay),
            layout: layout,
            theme: theme,
            goToLastTabOnClose: goToLastTabOnClose,
            switchShortcut: switchShortcut,
            searchShortcut: searchShortcut,
            searchWeights: searchWeights
        )
    }

    func save(_ settings: HudSettingsState) {
        let validation = validateShortcuts(switchShortcut: settings.switchShortcut, searchShortcut: settings.searchShortcut)
        guard validation.errors.isEmpty else { return }
        defaults.set(settings.enabled, forKey: HudSettingsDefaults.enabledKey)
        defaults.set(clampDelay(settings.hudDelay), forKey: HudSettingsDefaults.delayKey)
        defaults.set(settings.layout.rawValue, forKey: HudSettingsDefaults.layoutKey)
        defaults.set(settings.theme.rawValue, forKey: HudSettingsDefaults.themeKey)
        defaults.set(settings.goToLastTabOnClose, forKey: HudSettingsDefaults.goToLastTabOnCloseKey)
        persistShortcut(
            settings.switchShortcut,
            forKey: HudSettingsDefaults.switchShortcutKey,
            fallback: HudSettingsDefaults.defaultSwitchShortcut
        )
        persistShortcut(
            settings.searchShortcut,
            forKey: HudSettingsDefaults.searchShortcutKey,
            fallback: HudSettingsDefaults.defaultSearchShortcut
        )
        persistSearchWeights(
            settings.searchWeights,
            forKey: HudSettingsDefaults.searchWeightsKey,
            fallback: HudSettingsDefaults.defaultSearchWeights
        )
        defaults.set(Date().timeIntervalSince1970, forKey: HudSettingsDefaults.storageUpdatedAtKey)
        defaults.synchronize()
        DistributedNotificationCenter.default().post(name: HudSettingsDefaults.changedNotification, object: nil)
    }
}
#endif
