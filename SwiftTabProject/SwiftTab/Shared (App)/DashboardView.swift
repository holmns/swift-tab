#if os(macOS)
import SwiftUI
import AppKit

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case appearance
    case shortcuts
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .shortcuts: return "Shortcuts"
        case .advanced: return "Advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .shortcuts: return "keyboard"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct DashboardView: View {
    @ObservedObject var viewModel: MacOnboardingViewModel
    @StateObject private var hudSettingsViewModel = HudSettingsViewModel()
    @State private var selectedPane: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selectedPane) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch selectedPane ?? .general {
                case .general:
                    GeneralPane(viewModel: viewModel)
                case .appearance:
                    AppearancePane(settings: hudSettingsViewModel)
                case .shortcuts:
                    ShortcutsPane(settings: hudSettingsViewModel)
                case .advanced:
                    AdvancedPane(settings: hudSettingsViewModel)
                }
            }
            .navigationTitle((selectedPane ?? .general).title)
        }
        .task {
            viewModel.refreshExtensionState()
        }
    }
}

// MARK: - General

private struct GeneralPane: View {
    @ObservedObject var viewModel: MacOnboardingViewModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.extensionState.iconName)
                        .font(.title2)
                        .foregroundStyle(viewModel.extensionState.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.extensionState.displayTitle)
                            .font(.headline)
                        Text(viewModel.extensionState.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if viewModel.isCheckingExtensionState {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Refresh") {
                            viewModel.refreshExtensionState()
                        }
                    }
                }
                .padding(.vertical, 4)

                LabeledContent("Safari Extensions") {
                    Button(viewModel.isOpeningPreferences ? "Opening…" : "Open Safari Settings…") {
                        viewModel.openSafariPreferences()
                    }
                    .disabled(viewModel.isOpeningPreferences)
                }
            }

            Section {
                ForEach(EnablementStep.all) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.number)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(.quaternary.opacity(0.5)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                            Text(step.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Getting Started")
            }
        }
        .formStyle(.grouped)
    }
}

private struct EnablementStep: Identifiable {
    let id: Int
    let number: Int
    let title: String
    let detail: String

    static let all: [EnablementStep] = [
        .init(id: 1, number: 1, title: "Enable SwiftTab", detail: "Safari → Settings → Extensions → SwiftTab."),
        .init(id: 2, number: 2, title: "Learn the shortcuts", detail: "Use the defaults, or change them in Shortcuts."),
        .init(id: 3, number: 3, title: "Switch tabs swiftly", detail: "Press the shortcut in Safari to switch or search tabs.")
    ]
}

// MARK: - Appearance

private struct AppearancePane: View {
    @ObservedObject var settings: HudSettingsViewModel

    var body: some View {
        Form {
            Section {
                Picker("Layout", selection: $settings.layout) {
                    ForEach(HudLayoutMode.allCases) { layout in
                        Text(layout.label).tag(layout)
                    }
                }

                Picker("Theme", selection: $settings.theme) {
                    ForEach(HudThemeMode.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
            } footer: {
                Text("The vertical layout keeps long titles readable; horizontal fits more tabs on screen.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

private struct ShortcutsPane: View {
    @ObservedObject var settings: HudSettingsViewModel
    @State private var activeRecorderID: UUID?

    private var closeShortcutBinding: Binding<ShortcutSetting> {
        Binding(
            get: {
                ShortcutSetting(
                    key: settings.closeShortcutKey,
                    alt: settings.switchShortcut.alt,
                    ctrl: settings.switchShortcut.ctrl,
                    meta: settings.switchShortcut.meta,
                    shift: settings.switchShortcut.shift
                )
            },
            set: { newValue in
                settings.closeShortcutKey = normalizeCloseShortcutKey(
                    newValue.key,
                    fallback: HudSettingsDefaults.defaultCloseShortcutKey
                )
            }
        )
    }

    private var validation: ShortcutValidation {
        validateShortcuts(
            switchShortcut: settings.switchShortcut,
            closeShortcutKey: settings.closeShortcutKey,
            searchShortcut: settings.searchShortcut
        )
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Switch tabs") {
                    ShortcutRecorderField(
                        shortcut: $settings.switchShortcut,
                        activeRecorderID: $activeRecorderID
                    )
                }

                LabeledContent("Search tabs") {
                    ShortcutRecorderField(
                        shortcut: $settings.searchShortcut,
                        activeRecorderID: $activeRecorderID
                    )
                }

                LabeledContent("Close tab while switching") {
                    ShortcutRecorderField(
                        shortcut: closeShortcutBinding,
                        activeRecorderID: $activeRecorderID
                    )
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(validation.errors, id: \.self) { message in
                        Text(message)
                            .foregroundStyle(.red)
                    }
                    if validation.errors.isEmpty {
                        ForEach(validation.warnings, id: \.self) { message in
                            Text(message)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("Hold the modifiers to keep the switcher open; release them to confirm the highlighted tab. Closing a tab uses the same modifiers as Switch Tabs.")
                }
            }

            Section {
                Button("Restore Defaults") {
                    settings.switchShortcut = HudSettingsDefaults.defaultSwitchShortcut
                    settings.searchShortcut = HudSettingsDefaults.defaultSearchShortcut
                    settings.closeShortcutKey = HudSettingsDefaults.defaultCloseShortcutKey
                    activeRecorderID = nil
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced

private struct AdvancedPane: View {
    @ObservedObject var settings: HudSettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Return to last used tab", isOn: $settings.goToLastTabOnClose)

                LabeledContent("Show delay") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.hudDelay, in: 0...1000, step: 10)
                            .frame(width: 180)
                        Text("\(Int(settings.hudDelay)) ms")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            } header: {
                Text("Behavior")
            } footer: {
                Text("When you close the active tab, focus moves to the most recently used tab. The delay controls how long to wait before the switcher appears.")
            }

            Section {
                Picker("Title", selection: $settings.searchWeights.title) {
                    ForEach(SearchPriority.allCases) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }

                Picker("Hostname", selection: $settings.searchWeights.hostname) {
                    ForEach(SearchPriority.allCases) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }

                Picker("URL", selection: $settings.searchWeights.url) {
                    ForEach(SearchPriority.allCases) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }
            } header: {
                Text("Search Priority")
            } footer: {
                Text("How much search favors matches in the page title, the site's domain, or the full URL.")
            }

            Section {
                Button("Restore Defaults") {
                    settings.goToLastTabOnClose = HudSettingsDefaults.defaults.goToLastTabOnClose
                    settings.hudDelay = Double(HudSettingsDefaults.defaults.hudDelay)
                    settings.searchWeights = HudSettingsDefaults.defaultSearchWeights
                }
            }
        }
        .formStyle(.grouped)
    }
}

private extension SearchPriority {
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Shortcut recorder

private struct ShortcutRecorderField: View {
    @Binding var shortcut: ShortcutSetting
    @Binding var activeRecorderID: UUID?
    @State private var recorderID = UUID()
    @State private var eventMonitor: Any?

    private var isRecording: Bool { activeRecorderID == recorderID }

    var body: some View {
        Button {
            activeRecorderID = isRecording ? nil : recorderID
        } label: {
            Text(isRecording ? "Type shortcut…" : shortcut.displayText)
                .font(.body)
                .foregroundStyle(isRecording ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .padding(.vertical, 3)
                .padding(.horizontal, 10)
                .frame(minWidth: 110)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.quaternary.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isRecording ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Press the new shortcut, or Esc to cancel" : "Click to record a new shortcut")
        .onDisappear {
            removeMonitor()
            if isRecording {
                activeRecorderID = nil
            }
        }
        .onChange(of: activeRecorderID) { _, newValue in
            syncMonitor(isActive: newValue == recorderID)
        }
        .onAppear {
            syncMonitor(isActive: isRecording)
        }
    }

    private func syncMonitor(isActive: Bool) {
        if isActive {
            startMonitor()
        } else {
            removeMonitor()
        }
    }

    private func startMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event: event)
        }
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handle(event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 { // Escape cancels recording.
            activeRecorderID = nil
            return nil
        }
        guard let captured = ShortcutSetting.from(event: event) else {
            return nil
        }
        shortcut = captured
        activeRecorderID = nil
        return nil
    }
}

// MARK: - Extension state presentation

private extension MacOnboardingViewModel.ExtensionState {
    var displayTitle: String {
        switch self {
        case .unknown:
            return "Status unknown"
        case .enabled:
            return "SwiftTab is enabled"
        case .disabled:
            return "SwiftTab is turned off"
        case .error:
            return "Unable to confirm status"
        }
    }

    var detail: String {
        switch self {
        case .unknown:
            return "Click Refresh to check Safari's extension status."
        case .enabled:
            return "You can start using SwiftTab in Safari."
        case .disabled:
            return "Open Safari Settings to enable the extension."
        case .error(let message):
            return message
        }
    }

    var iconName: String {
        switch self {
        case .enabled:
            return "checkmark.circle.fill"
        case .disabled:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .enabled:
            return .green
        case .disabled:
            return .orange
        case .unknown:
            return .secondary
        case .error:
            return .red
        }
    }
}

#Preview("DashBoardView") {
    DashboardView(viewModel: MacOnboardingViewModel())
        .frame(minWidth: 760, minHeight: 540)
}
#endif
