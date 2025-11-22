#if os(macOS)
import Foundation

enum HudLayoutMode: String, CaseIterable, Identifiable {
    case vertical
    case horizontal
    
    var id: String { rawValue }

    var label: String {
        switch self {
        case .vertical:
            return "Vertical list"
        case .horizontal:
            return "Horizontal grid"
        }
    }
}

enum HudThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return "Follow device"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

struct HudSettingsState {
    var enabled: Bool
    var hudDelay: Int
    var layout: HudLayoutMode
    var theme: HudThemeMode
    var goToLastTabOnClose: Bool
}

enum HudSettingsDefaults {
    static let groupIdentifier = "group.com.holmns.swifttab"
    static let storageUpdatedAtKey = "swiftTab.hudSettings.updatedAt"
    static let enabledKey = "swiftTab.hudSettings.enabled"
    static let delayKey = "swiftTab.hudSettings.hudDelay"
    static let layoutKey = "swiftTab.hudSettings.layout"
    static let themeKey = "swiftTab.hudSettings.theme"
    static let goToLastTabOnCloseKey = "swiftTab.hudSettings.goToLastTabOnClose"
    static let changedNotification = Notification.Name("com.holmns.swifttab.settingsChanged")

    static let defaults = HudSettingsState(
        enabled: true,
        hudDelay: 100,
        layout: .vertical,
        theme: .system,
        goToLastTabOnClose: true
    )
}
#endif
