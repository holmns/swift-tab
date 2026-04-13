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

enum SearchPriority: String, CaseIterable, Identifiable {
    case off
    case low
    case medium
    case high

    var id: String { rawValue }

    var weight: Int {
        switch self {
        case .off: return 0
        case .low: return 1
        case .medium: return 3
        case .high: return 5
        }
    }

    static func fromWeight(_ weight: Int) -> SearchPriority {
        switch weight {
        case ..<1:
            return .off
        case 1:
            return .low
        case 2...4:
            return .medium
        default:
            return .high
        }
    }
}

struct SearchWeights: Equatable {
    var title: SearchPriority
    var hostname: SearchPriority
    var url: SearchPriority

    static let `default` = SearchWeights(title: .medium, hostname: .high, url: .low)

    var storageValue: [String: Any] {
        [
            "title": title.weight,
            "hostname": hostname.weight,
            "url": url.weight
        ]
    }

    static func fromStorage(_ value: Any?, fallback: SearchWeights = .default) -> SearchWeights {
        guard let dict = value as? [String: Any] else { return fallback }
        let titleWeight = dict["title"] as? Int ?? fallback.title.weight
        let hostnameWeight = dict["hostname"] as? Int ?? fallback.hostname.weight
        let urlWeight = dict["url"] as? Int ?? fallback.url.weight
        return SearchWeights(
            title: SearchPriority.fromWeight(titleWeight),
            hostname: SearchPriority.fromWeight(hostnameWeight),
            url: SearchPriority.fromWeight(urlWeight)
        )
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

    static func keyString(from event: NSEvent) -> String? {
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

func normalizeCloseShortcutKey(_ value: String?, fallback: String) -> String {
    guard let value else { return fallback }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return fallback }
    let normalized = ShortcutSetting(
        key: trimmed,
        alt: false,
        ctrl: false,
        meta: false,
        shift: false
    ).normalizedKey
    return normalized.isEmpty ? fallback : normalized
}

func resolveCloseShortcutKey(
    _ closeKey: String,
    switchShortcut: ShortcutSetting,
    searchShortcut: ShortcutSetting,
    fallback: String
) -> String {
    let normalizedSwitch = switchShortcut.normalizedKey
    let normalizedSearch = searchShortcut.normalizedKey
    let candidates = [
        normalizeCloseShortcutKey(closeKey, fallback: fallback),
        fallback,
        HudSettingsDefaults.defaultCloseShortcutKey,
        "delete",
        "backspace"
    ]

    for candidate in candidates {
        guard !candidate.isEmpty else { continue }
        let normalized = normalizeCloseShortcutKey(candidate, fallback: fallback)
        if normalized == normalizedSwitch || normalized == normalizedSearch { continue }
        return normalized
    }

    return HudSettingsDefaults.defaultCloseShortcutKey
}

struct HudSettingsState: Equatable {
    var enabled: Bool
    var hudDelay: Int
    var layout: HudLayoutMode
    var theme: HudThemeMode
    var goToLastTabOnClose: Bool
    var closeShortcutKey: String
    var switchShortcut: ShortcutSetting
    var searchShortcut: ShortcutSetting
    var searchWeights: SearchWeights
}

enum HudSettingsDefaults {
    static let groupIdentifier = "group.com.holmns.swifttab"
    static let storageUpdatedAtKey = "swifttab.hudSettings.updatedAt"
    static let enabledKey = "swifttab.hudSettings.enabled"
    static let delayKey = "swifttab.hudSettings.hudDelay"
    static let layoutKey = "swifttab.hudSettings.layout"
    static let themeKey = "swifttab.hudSettings.theme"
    static let goToLastTabOnCloseKey = "swifttab.hudSettings.goToLastTabOnClose"
    static let closeShortcutKeyKey = "swifttab.hudSettings.closeShortcutKey"
    static let switchShortcutKey = "swifttab.hudSettings.switchShortcut"
    static let searchShortcutKey = "swifttab.hudSettings.searchShortcut"
    static let searchWeightsKey = "swifttab.hudSettings.searchWeights"
    static let changedNotification = Notification.Name("com.holmns.swifttab.settingsChanged")
    static let defaultSwitchShortcut = ShortcutSetting(key: "tab", alt: true, ctrl: false, meta: false, shift: false)
    static let defaultSearchShortcut = ShortcutSetting(key: "space", alt: true, ctrl: false, meta: false, shift: false)
    static let defaultCloseShortcutKey = "w"
    static let defaultSearchWeights = SearchWeights.default

    static let defaults = HudSettingsState(
        enabled: true,
        hudDelay: 100,
        layout: .vertical,
        theme: .system,
        goToLastTabOnClose: true,
        closeShortcutKey: defaultCloseShortcutKey,
        switchShortcut: defaultSwitchShortcut,
        searchShortcut: defaultSearchShortcut,
        searchWeights: defaultSearchWeights
    )
}

struct ShortcutValidation {
    let errors: [String]
    let warnings: [String]
    var isValid: Bool { errors.isEmpty }
}

private func hasModifier(_ shortcut: ShortcutSetting) -> Bool {
    shortcut.alt || shortcut.ctrl || shortcut.meta || shortcut.shift
}

private func matches(_ shortcut: ShortcutSetting, key: String, alt: Bool = false, ctrl: Bool = false, meta: Bool = false, shift: Bool = false) -> Bool {
    shortcut.normalizedKey == key && shortcut.alt == alt && shortcut.ctrl == ctrl && shortcut.meta == meta && shortcut.shift == shift
}

private func conflictWarnings(for shortcut: ShortcutSetting, label: String) -> [String] {
    var messages: [String] = []

    let likelyConflicts: [(ShortcutSetting) -> Bool] = [
        { matches($0, key: "space", meta: true) },
        { matches($0, key: "space", ctrl: true) },
        { matches($0, key: "tab", meta: true) || matches($0, key: "tab", meta: true, shift: true) },
        { matches($0, key: "tab", ctrl: true) || matches($0, key: "tab", ctrl: true, shift: true) },
        { matches($0, key: "escape", alt: true, meta: true) },
        { matches($0, key: "h", meta: true) },
        { matches($0, key: "w", meta: true) },
        { matches($0, key: "q", meta: true) },
        { matches($0, key: "l", meta: true) },
        { matches($0, key: "t", meta: true) || matches($0, key: "t", meta: true, shift: true) },
        { matches($0, key: "f", meta: true) },
        { matches($0, key: "=", meta: true) || matches($0, key: "+", meta: true) || matches($0, key: "-", meta: true) },
        { matches($0, key: "[", meta: true) || matches($0, key: "]", meta: true) }
    ]

    if likelyConflicts.contains(where: { $0(shortcut) }) {
        messages.append("\(label) may conflict with system or app shortcuts.")
    }

    return messages
}

func validateShortcuts(switchShortcut: ShortcutSetting, closeShortcutKey: String, searchShortcut: ShortcutSetting) -> ShortcutValidation {
    var errors: [String] = []
    var warnings: [String] = []
    let closeShortcut = ShortcutSetting(
        key: closeShortcutKey,
        alt: switchShortcut.alt,
        ctrl: switchShortcut.ctrl,
        meta: switchShortcut.meta,
        shift: switchShortcut.shift
    )

    if switchShortcut == searchShortcut {
        errors.append("Shortcuts must differ. Pick a different combo for search or switch.")
    }
    
    if closeShortcut == switchShortcut {
        errors.append("Close shortcut cannot be the same as the Tab switcher shortcut.")
    }
    
    if closeShortcut == searchShortcut {
        errors.append("Close shortcut cannot be the same as the Search shortcut.")
    }

    if !hasModifier(switchShortcut) {
        errors.append("Tab switcher shortcut needs at least one modifier (⌘, ⌥, ⌃, or ⇧).")
    }

    if !hasModifier(searchShortcut) {
        errors.append("Search shortcut needs at least one modifier (⌘, ⌥, ⌃, or ⇧).")
    }

    warnings.append(contentsOf: conflictWarnings(for: switchShortcut, label: "Tab switcher shortcut"))
    warnings.append(contentsOf: conflictWarnings(for: searchShortcut, label: "Search shortcut"))

    return ShortcutValidation(errors: errors, warnings: warnings)
}
#endif
