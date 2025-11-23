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
            case .backspace:
                return "backspace"
            case .carriageReturn, .newline, .enter:
                return "enter"
            case .tab:
                return "tab"
            case .backTab:
                return "backtab"
            case .delete:
                return "delete"
            case .deleteForward:
                return "deleteforward"
            case .upArrow:
                return "arrowup"
            case .downArrow:
                return "arrowdown"
            case .leftArrow:
                return "arrowleft"
            case .rightArrow:
                return "arrowright"
            case .pageUp:
                return "pageup"
            case .pageDown:
                return "pagedown"
            case .home:
                return "home"
            case .end:
                return "end"
            case .prev:
                return "prev"
            case .next:
                return "next"
            case .begin:
                return "begin"
            case .break:
                return "break"
            case .clearDisplay:
                return "cleardisplay"
            case .clearLine:
                return "clearline"
            case .deleteCharacter:
                return "deletecharacter"
            case .deleteLine:
                return "deleteline"
            case .execute:
                return "execute"
            case .find:
                return "find"
            case .formFeed:
                return "formfeed"
            case .help:
                return "help"
            case .insert:
                return "insert"
            case .insertCharacter:
                return "insertcharacter"
            case .insertLine:
                return "insertline"
            case .lineSeparator:
                return "lineseparator"
            case .menu:
                return "menu"
            case .modeSwitch:
                return "modeswitch"
            case .paragraphSeparator:
                return "paragraphseparator"
            case .pause:
                return "pause"
            case .print:
                return "print"
            case .printScreen:
                return "printscreen"
            case .redo:
                return "redo"
            case .reset:
                return "reset"
            case .scrollLock:
                return "scrolllock"
            case .select:
                return "select"
            case .stop:
                return "stop"
            case .sysReq:
                return "sysreq"
            case .system:
                return "system"
            case .undo:
                return "undo"
            case .user:
                return "user"
            case .f1: return "f1"
            case .f2: return "f2"
            case .f3: return "f3"
            case .f4: return "f4"
            case .f5: return "f5"
            case .f6: return "f6"
            case .f7: return "f7"
            case .f8: return "f8"
            case .f9: return "f9"
            case .f10: return "f10"
            case .f11: return "f11"
            case .f12: return "f12"
            case .f13: return "f13"
            case .f14: return "f14"
            case .f15: return "f15"
            case .f16: return "f16"
            case .f17: return "f17"
            case .f18: return "f18"
            case .f19: return "f19"
            case .f20: return "f20"
            case .f21: return "f21"
            case .f22: return "f22"
            case .f23: return "f23"
            case .f24: return "f24"
            case .f25: return "f25"
            case .f26: return "f26"
            case .f27: return "f27"
            case .f28: return "f28"
            case .f29: return "f29"
            case .f30: return "f30"
            case .f31: return "f31"
            case .f32: return "f32"
            case .f33: return "f33"
            case .f34: return "f34"
            case .f35: return "f35"
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
        case "backspace", "delete":
            return "Delete"
        case "deleteforward":
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
    static let storageUpdatedAtKey = "swifttab.hudSettings.updatedAt"
    static let enabledKey = "swifttab.hudSettings.enabled"
    static let delayKey = "swifttab.hudSettings.hudDelay"
    static let layoutKey = "swifttab.hudSettings.layout"
    static let themeKey = "swifttab.hudSettings.theme"
    static let goToLastTabOnCloseKey = "swifttab.hudSettings.goToLastTabOnClose"
    static let switchShortcutKey = "swifttab.hudSettings.switchShortcut"
    static let searchShortcutKey = "swifttab.hudSettings.searchShortcut"
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
