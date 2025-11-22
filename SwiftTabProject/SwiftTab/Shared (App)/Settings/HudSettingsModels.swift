#if os(macOS)
import AppKit
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

struct ShortcutSetting: Equatable {
    var key: String
    var alt: Bool
    var ctrl: Bool
    var meta: Bool
    var shift: Bool

    var normalizedKey: String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "spacebar" || trimmed == " " { return "space" }
        if trimmed == "\t" { return "tab" }
        return trimmed
    }

    var storageValue: [String: Any] {
        [
            "key": normalizedKey,
            "alt": alt,
            "ctrl": ctrl,
            "meta": meta,
            "shift": shift
        ]
    }

    var displayText: String {
        let modifiers: [String] = [
            ctrl ? "⌃" : nil,
            alt ? "⌥" : nil,
            shift ? "⇧" : nil,
            meta ? "⌘" : nil
        ].compactMap { $0 }
        let keyLabel = keyDisplayLabel
        guard !keyLabel.isEmpty else { return "Not set" }
        if modifiers.isEmpty {
            return keyLabel
        }
        return (modifiers + [keyLabel]).joined(separator: " ")
    }

    func normalized(fallback: ShortcutSetting) -> ShortcutSetting {
        let keyValue = normalizedKey
        if keyValue.isEmpty {
            return fallback
        }
        return ShortcutSetting(key: keyValue, alt: alt, ctrl: ctrl, meta: meta, shift: shift)
    }

    static func fromStorage(_ value: Any?, fallback: ShortcutSetting) -> ShortcutSetting {
        guard let dict = value as? [String: Any] else {
            return fallback
        }
        let rawKey = dict["key"] as? String ?? fallback.key
        let alt = dict["alt"] as? Bool ?? fallback.alt
        let ctrl = dict["ctrl"] as? Bool ?? fallback.ctrl
        let meta = dict["meta"] as? Bool ?? fallback.meta
        let shift = dict["shift"] as? Bool ?? fallback.shift
        let parsed = ShortcutSetting(key: rawKey, alt: alt, ctrl: ctrl, meta: meta, shift: shift)
        return parsed.normalized(fallback: fallback)
    }

    static func from(event: NSEvent) -> ShortcutSetting? {
        guard let keyString = keyString(from: event) else { return nil }
        let flags = event.modifierFlags
        let setting = ShortcutSetting(
            key: keyString,
            alt: flags.contains(.option),
            ctrl: flags.contains(.control),
            meta: flags.contains(.command),
            shift: flags.contains(.shift)
        )
        return setting.normalized(fallback: setting)
    }

    private static func keyString(from event: NSEvent) -> String? {
        // Prefer physical key codes for common keys not exposed via SpecialKey on older SDKs.
        switch event.keyCode {
        case 53:
            return "escape"
        case 36, 76:
            return "enter"
        case 49:
            return "space"
        default:
            break
        }

        if let specialKey = event.specialKey {
            switch specialKey {
            case .tab:
                return "tab"
            case .delete:
                return "backspace"
            case .deleteForward:
                return "delete"
            case .home:
                return "home"
            case .end:
                return "end"
            case .pageUp:
                return "pageup"
            case .pageDown:
                return "pagedown"
            case .leftArrow:
                return "arrowleft"
            case .rightArrow:
                return "arrowright"
            case .upArrow:
                return "arrowup"
            case .downArrow:
                return "arrowdown"
            default:
                break
            }
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return nil
        }

        if characters == "\t" {
            return "tab"
        }

        if characters == " " {
            return "space"
        }

        let trimmed = characters.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    var keyDisplayLabel: String {
        let normalized = normalizedKey
        switch normalized {
        case "space":
            return "Space"
        case "tab":
            return "Tab"
        case "escape":
            return "Esc"
        case "enter":
            return "Enter"
        case "backspace":
            return "Delete"
        case "delete":
            return "Forward Delete"
        case "arrowleft":
            return "←"
        case "arrowright":
            return "→"
        case "arrowup":
            return "↑"
        case "arrowdown":
            return "↓"
        default:
            if normalized.count == 1 {
                return normalized.uppercased()
            }
            return normalized.capitalized
        }
    }
}

struct HudSettingsState {
    var enabled: Bool
    var hudDelay: Int
    var layout: HudLayoutMode
    var theme: HudThemeMode
    var goToLastTabOnClose: Bool
    var switchShortcut: ShortcutSetting
    var searchShortcut: ShortcutSetting
}

enum HudSettingsDefaults {
    static let groupIdentifier = "group.com.holmns.swifttab"
    static let storageUpdatedAtKey = "swiftTab.hudSettings.updatedAt"
    static let enabledKey = "swiftTab.hudSettings.enabled"
    static let delayKey = "swiftTab.hudSettings.hudDelay"
    static let layoutKey = "swiftTab.hudSettings.layout"
    static let themeKey = "swiftTab.hudSettings.theme"
    static let goToLastTabOnCloseKey = "swiftTab.hudSettings.goToLastTabOnClose"
    static let switchShortcutKey = "swiftTab.hudSettings.switchShortcut"
    static let searchShortcutKey = "swiftTab.hudSettings.searchShortcut"
    static let changedNotification = Notification.Name("com.holmns.swifttab.settingsChanged")
    static let defaultSwitchShortcut = ShortcutSetting(key: "tab", alt: true, ctrl: false, meta: false, shift: false)
    static let defaultSearchShortcut = ShortcutSetting(key: "space", alt: true, ctrl: false, meta: false, shift: false)

    static let defaults = HudSettingsState(
        enabled: true,
        hudDelay: 100,
        layout: .vertical,
        theme: .system,
        goToLastTabOnClose: true,
        switchShortcut: defaultSwitchShortcut,
        searchShortcut: defaultSearchShortcut
    )
}
#endif
