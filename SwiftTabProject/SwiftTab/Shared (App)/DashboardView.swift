#if os(macOS)
import SwiftUI
import AppKit

struct DashboardView: View {
    @ObservedObject var viewModel: MacOnboardingViewModel
    @StateObject private var hudSettingsViewModel = HudSettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SwiftTab Dashboard")
                        .font(.system(size: 30, weight: .bold))
                    Text("Enable the extension, verify status, and keep exploring.")
                        .foregroundStyle(.secondary)
                }
                
                HStack(alignment: .top, spacing: 20) {
                    statusCard
                    EnablementStepsCard()
                }
                HudSettingsCard(viewModel: hudSettingsViewModel)
                    .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .padding(36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .task {
            viewModel.refreshExtensionState()
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {

                Image(systemName: viewModel.extensionState.iconName)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(
                        viewModel.extensionState.accentColor,
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.extensionState.displayTitle)
                        .font(.title2.weight(.semibold))
                    Text(viewModel.extensionState.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.openSafariPreferences()
                } label: {
                    if viewModel.isOpeningPreferences {
                        ProgressView()
                            .controlSize(.small)
                        Text("Opening Safari…")
                    } else {
                        Text("Open Safari Settings")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isOpeningPreferences)

                Button("Refresh Status", action: viewModel.refreshExtensionState)
                    .disabled(viewModel.isCheckingExtensionState)
                
                if viewModel.isCheckingExtensionState {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking Safari extension status…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct EnablementStepsCard: View {
    private let steps = EnablementStep.sample
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(step.number)")
                        .font(.headline)
                        .frame(width: 26, height: 26)
                        .foregroundStyle(.white)
                        .background(step.color, in: Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.headline)
                        Text(step.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct EnablementStep: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
    let detail: String
    let color: Color
    
    static let sample: [EnablementStep] = [
        .init(number: 1, title: "Enable SwiftTab", detail: "Safari → Settings → Extensions → SwiftTab → check the box.", color: Color(red: 0.55, green: 0.34, blue: 0.96)),
        .init(number: 2, title: "Approve Shortcut", detail: "Use default shortcuts or assign shortcuts in the settings below.", color: Color(red: 0.26, green: 0.58, blue: 0.9)),
        .init(number: 3, title: "Switch Tabs Swiftly", detail: "Press the shortcut to switch between tabs or search them.", color: Color(red: 0.23, green: 0.64, blue: 0.5))
    ]
}

private struct HudSettingsCard: View {
    @ObservedObject var viewModel: HudSettingsViewModel
    @State private var showAdvanced = false
    @State private var showWarning = false
    @State private var warningMessage: String = ""
    @State private var warningLevel: BannerLevel = .warning
    @State private var warningTask: DispatchWorkItem?
    @State private var activeRecorderID: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SwiftTab Settings")
                .font(.title.weight(.bold))
            
            Text("Appearance")
                .font(.title3.bold())
                .padding(.top, 4)
            
            SettingRow(title: "Layout", subtitle: "Vertical keeps long titles readable, horizontal fits more tabs on screen.") {
                Picker("", selection: $viewModel.layout) {
                    ForEach(HudLayoutMode.allCases) { layout in
                        Text(layout.label).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
            }

            SettingRow(title: "Theme", subtitle: "Customize how the UI looks") {
                Picker("", selection: $viewModel.theme) {
                    ForEach(HudThemeMode.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
            }
            
            separator
            
            Text("Shortcuts")
                .font(.title3.bold())
                .padding(.top, 4)
            
            SettingRow(title: "Tab switcher", subtitle: "Hold the modifiers to keep the UI visible, release to confirm the highlighted tab.") {
                ShortcutRecorderField(
                    shortcut: $viewModel.switchShortcut,
                    activeRecorderID: $activeRecorderID,
                    defaultShortcut: HudSettingsDefaults.defaultSwitchShortcut
                )
            }
            .padding(.bottom, 24)
            
            SettingRow(title: "Search tabs", subtitle: "Opens the searchable UI immediately.") {
                ShortcutRecorderField(
                    shortcut: $viewModel.searchShortcut,
                    activeRecorderID: $activeRecorderID,
                    defaultShortcut: HudSettingsDefaults.defaultSearchShortcut
                )
            }
            .padding(.bottom, 8)

            if showWarning {
                Text(warningMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(warningLevel == .error ? Color.red : Color.yellow)
                    .padding(.top, 4)
            }
            
            separator
            
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack {
                    Text("Advanced Settings")
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(showAdvanced ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: showAdvanced)
                }
                .padding(.trailing, 20)
                .padding(.vertical, 10)
                .contentShape(Rectangle().inset(by: -50))
            }
            .buttonStyle(PlainButtonStyle())
            
            if showAdvanced {
                VStack(alignment: .leading, spacing: 18) {
                    
                    SettingRow(title: "Return to last used tab", subtitle: "When you close the active tab, focus the most recently used tab automatically.") {
                        Toggle(isOn: $viewModel.goToLastTabOnClose) {}
                            .toggleStyle(.switch)
                    }
                    
                    SettingRow(title: "UI Delay", subtitle: "Delay before the UI shows after holding modifier key during tab switching.") {
                        HStack(spacing: 5) {
                            Text("\(Int(viewModel.hudDelay)) ms")
                                .font(.footnote.monospacedDigit())
                                .frame(width: 70, alignment: .trailing)
                                .foregroundStyle(.secondary)
                            Slider(value: $viewModel.hudDelay, in: 0...1000, step: 10)
                                .frame(maxWidth: 300)
                        }
                        
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                )
        )
        .onChange(of: viewModel.switchShortcut) {
            validateAndShowError()
        }
        .onChange(of: viewModel.searchShortcut) {
            validateAndShowError()
        }
        .onAppear {
            validateAndShowError()
        }
        .onDisappear {
            warningTask?.cancel()
        }
    }
    
    var separator: some View {
        Rectangle()
            .foregroundStyle(.quaternary)
            .frame(height: 1)
    }

    private func validateAndShowError() {
        let validation = validateShortcuts(
            switchShortcut: viewModel.switchShortcut,
            searchShortcut: viewModel.searchShortcut
        )

        if let error = validation.errors.first {
            showWarningMessage(error, level: .error)
            return
        }

        if let warning = validation.warnings.first {
            showWarningMessage(warning, level: .warning)
            return
        }
    }

    private func showWarningMessage(_ message: String, level: BannerLevel) {
        warningTask?.cancel()
        warningMessage = message
        warningLevel = level
        withAnimation(.spring(duration: 0.2)) {
            showWarning = true
        }
        let task = DispatchWorkItem {
            withAnimation {
                showWarning = false
            }
        }
        warningTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }
}

private struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let selector: () -> Content
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            selector()
        }
    }
}

private enum BannerLevel {
    case warning
    case error
}

private struct ShortcutRecorderField: View {
    @Binding var shortcut: ShortcutSetting
    @Binding var activeRecorderID: UUID?
    @State private var recorderID = UUID()
    @State private var eventMonitor: Any?
    let defaultShortcut: ShortcutSetting
    
    private var isRecording: Bool { activeRecorderID == recorderID }

    var body: some View {
        Button {
            if isRecording {
                activeRecorderID = nil
            } else {
                activeRecorderID = recorderID
            }
        } label: {
            HStack(spacing: 4) {
                Group {
                    Text("⇧")
                        .foregroundStyle(shortcut.shift ? .primary : .quaternary)
                    Text("⌃")
                        .foregroundStyle(shortcut.ctrl ? .primary : .quaternary)
                    Text("⌥")
                        .foregroundStyle(shortcut.alt ? .primary : .quaternary)
                    Text("⌘")
                        .foregroundStyle(shortcut.meta ? .primary : .quaternary)
                }
                .font(.title3.bold())
                Text(shortcut.keyDisplayLabel)
                    .font(.body.bold())
                
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(minWidth: 180, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isRecording ? Color.secondary : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            Button {
                shortcut = defaultShortcut
                if isRecording {
                    activeRecorderID = nil
                }
            } label: {
                Text("Reset")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .offset(y: -32)
        }
        .overlay(alignment: .center) {
            if isRecording {
                Text("Recording... Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .offset(y: 32)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
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
            return "Click Refresh to check Safari’s extension status."
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
            return "checkmark.seal.fill"
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
            return Color.green
        case .disabled:
            return Color.orange
        case .unknown:
            return Color.accentColor
        case .error:
            return Color.red
        }
    }
}

#Preview("DashBoardView") {
    DashboardView(viewModel: MacOnboardingViewModel())
        .frame(minWidth: 1200, minHeight: 1000)
}
#endif
