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

            if viewModel.isCheckingExtensionState {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking Safari extension status…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.openSafariPreferences()
                } label: {
                    if viewModel.isOpeningPreferences {
                        ProgressView()
                            .controlSize(.regular)
                            .frame(width: 16, height: 16)
                        Text("Opening Safari…")
                    } else {
                        Text("Open Safari Settings")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isOpeningPreferences)

                Button("Refresh Status", action: viewModel.refreshExtensionState)
                    .disabled(viewModel.isCheckingExtensionState)
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
        .init(number: 2, title: "Approve Shortcut", detail: "Assign a shortcut under Safari → Settings → Extensions → SwiftTab → Shortcuts.", color: Color(red: 0.26, green: 0.58, blue: 0.9)),
        .init(number: 3, title: "Practice Switching", detail: "Hold ⌥ to keep the HUD visible, release to confirm the highlighted tab.", color: Color(red: 0.23, green: 0.64, blue: 0.5))
    ]
}

private struct HudSettingsCard: View {
    @ObservedObject var viewModel: HudSettingsViewModel
    @State private var showAdvanced = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SwiftTab Settings")
                .font(.title3.weight(.semibold))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Layout")
                    .font(.headline)
                Picker("Layout", selection: $viewModel.layout) {
                    ForEach(HudLayoutMode.allCases) { layout in
                        Text(layout.label).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
                Text("Vertical keeps long titles readable, horizontal fits more tabs on screen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.headline)
                Picker("Theme", selection: $viewModel.theme) {
                    ForEach(HudThemeMode.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
                Text("Follow device tracks macOS appearance automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Shortcuts")
                    .font(.headline)
                ShortcutRecorderRow(
                    title: "Tab switcher",
                    subtitle: "Hold the modifiers to keep the HUD visible, release to confirm the highlighted tab.",
                    shortcut: $viewModel.switchShortcut,
                    defaultShortcut: HudSettingsDefaults.defaultSwitchShortcut
                )
                ShortcutRecorderRow(
                    title: "Search tabs",
                    subtitle: "Opens the searchable HUD immediately.",
                    shortcut: $viewModel.searchShortcut,
                    defaultShortcut: HudSettingsDefaults.defaultSearchShortcut
                )
            }
            
            VStack(alignment: .leading, spacing: 10) {
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
                    .padding(.trailing, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(PlainButtonStyle())

                if showAdvanced {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $viewModel.goToLastTabOnClose) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Return to last used tab")
                                    .font(.body.weight(.semibold))
                                Text("When you close the active tab, focus the most recently used tab automatically.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("HUD Delay")
                                .font(.headline)
                            HStack {
                                Slider(value: $viewModel.hudDelay, in: 0...1000, step: 10)
                                Text("\(Int(viewModel.hudDelay)) ms")
                                    .font(.footnote.monospacedDigit())
                                    .frame(width: 70, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Delay before the HUD shows after holding ⌥ during tab switching.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
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
    }
}

private struct ShortcutRecorderRow: View {
    let title: String
    let subtitle: String
    @Binding var shortcut: ShortcutSetting
    let defaultShortcut: ShortcutSetting

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.body.weight(.semibold))
                Spacer()
                Button {
                    shortcut = defaultShortcut
                } label: {
                    Text("Reset")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ShortcutRecorderField(shortcut: $shortcut)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ShortcutRecorderField: View {
    @Binding var shortcut: ShortcutSetting
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                Text(shortcut.displayText)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(minWidth: 180, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )

            Spacer()

            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isRecording ? "dot.radiowaves.left.and.right" : "pencil")
                    Text(isRecording ? "Recording…" : "Change")
                }
                .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 4)
        .overlay(alignment: .trailing) {
            if isRecording {
                Text("Press a shortcut, Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 6)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event: event)
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }

    private func handle(event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 { // Escape cancels recording.
            stopRecording()
            return nil
        }
        guard let captured = ShortcutSetting.from(event: event) else {
            return nil
        }
        shortcut = captured
        stopRecording()
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
            return "You can start using ⌥ + Tab in Safari immediately."
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
        .frame(minWidth: 1257, minHeight: 768)
}
#endif
