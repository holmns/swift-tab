#if os(macOS)
import Foundation

enum HudLayoutMode: String, CaseIterable, Identifiable {
    case horizontal
    case vertical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .horizontal:
            return "Horizontal grid"
        case .vertical:
            return "Vertical list"
        }
    }
}

enum HudThemeMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "Follow device"
        }
    }
}

struct HudSettingsState {
    var enabled: Bool
    var hudDelay: Int
    var layout: HudLayoutMode
    var theme: HudThemeMode
}

enum HudSettingsDefaults {
    static let groupIdentifier = "group.com.holmns.swifttab"
    static let storageUpdatedAtKey = "swiftTab.hudSettings.updatedAt"
    static let enabledKey = "swiftTab.hudSettings.enabled"
    static let delayKey = "swiftTab.hudSettings.hudDelay"
    static let layoutKey = "swiftTab.hudSettings.layout"
    static let themeKey = "swiftTab.hudSettings.theme"
    static let changedNotification = Notification.Name("com.holmns.swifttab.settingsChanged")

    static let defaults = HudSettingsState(
        enabled: true,
        hudDelay: 100,
        layout: .vertical,
        theme: .system
    )
}
#endif
