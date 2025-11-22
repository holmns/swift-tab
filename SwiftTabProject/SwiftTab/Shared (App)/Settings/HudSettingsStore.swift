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

    func load() -> HudSettingsState {
        let enabled = defaults.object(forKey: HudSettingsDefaults.enabledKey) as? Bool
            ?? HudSettingsDefaults.defaults.enabled
        let delay = defaults.object(forKey: HudSettingsDefaults.delayKey) as? Int
            ?? HudSettingsDefaults.defaults.hudDelay
        let layout = HudLayoutMode(rawValue: defaults.string(forKey: HudSettingsDefaults.layoutKey) ?? "")
            ?? HudSettingsDefaults.defaults.layout
        let theme = HudThemeMode(rawValue: defaults.string(forKey: HudSettingsDefaults.themeKey) ?? "")
            ?? HudSettingsDefaults.defaults.theme

        return HudSettingsState(
            enabled: enabled,
            hudDelay: clampDelay(delay),
            layout: layout,
            theme: theme
        )
    }

    func save(_ settings: HudSettingsState) {
        defaults.set(settings.enabled, forKey: HudSettingsDefaults.enabledKey)
        defaults.set(clampDelay(settings.hudDelay), forKey: HudSettingsDefaults.delayKey)
        defaults.set(settings.layout.rawValue, forKey: HudSettingsDefaults.layoutKey)
        defaults.set(settings.theme.rawValue, forKey: HudSettingsDefaults.themeKey)
        defaults.set(Date().timeIntervalSince1970, forKey: HudSettingsDefaults.storageUpdatedAtKey)
        defaults.synchronize()
        DistributedNotificationCenter.default().post(name: HudSettingsDefaults.changedNotification, object: nil)
    }
}
#endif
