#if os(macOS)
import SwiftUI
import AppKit
import Combine

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
    case dark
    case light
    case system

    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark:
            return "Dark"
        case .light:
            return "Light"
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

private enum HudSettingsDefaults {
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

final class HudSettingsStore {
    static let shared = HudSettingsStore()

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: HudSettingsDefaults.groupIdentifier) ?? .standard
    }

    private func clampDelay(_ raw: Int) -> Int {
        if raw < 0 { return 0 }
        if raw > 1000 { return 1000 }
        return raw
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

final class HudSettingsViewModel: ObservableObject {
    @Published var hudDelay: Double
    @Published var layout: HudLayoutMode
    @Published var theme: HudThemeMode

    private var cancellables: Set<AnyCancellable> = []
    private var enabled: Bool
    private var isUpdatingFromStore = false

    private let store: HudSettingsStore

    init(store: HudSettingsStore = .shared) {
        self.store = store
        let settings = store.load()
        hudDelay = Double(settings.hudDelay)
        layout = settings.layout
        theme = settings.theme
        enabled = settings.enabled

        DistributedNotificationCenter.default()
            .publisher(for: HudSettingsDefaults.changedNotification)
            .sink { [weak self] _ in
                self?.refreshFromStore()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3($hudDelay, $layout, $theme)
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] delay, layout, theme in
                self?.persist(delay: delay, layout: layout, theme: theme)
            }
            .store(in: &cancellables)
    }

    private func refreshFromStore() {
        isUpdatingFromStore = true
        let latest = store.load()
        enabled = latest.enabled
        hudDelay = Double(latest.hudDelay)
        layout = latest.layout
        theme = latest.theme
        isUpdatingFromStore = false
    }

    private func persist(delay: Double, layout: HudLayoutMode, theme: HudThemeMode) {
        guard !isUpdatingFromStore else { return }
        let clampedDelay = max(0, min(1000, Int(delay.rounded())))
        let next = HudSettingsState(
            enabled: enabled,
            hudDelay: clampedDelay,
            layout: layout,
            theme: theme
        )
        store.save(next)
    }
}

struct DashboardView: View {
    @ObservedObject var viewModel: MacOnboardingViewModel
    @StateObject private var hudSettingsViewModel = HudSettingsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SwiftTab Dashboard")
                    .font(.system(size: 30, weight: .bold))
                Text("Enable the extension, verify status, and keep exploring.")
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 20) {
                StatusCard
                EnablementStepsCard()
            }

            HudSettingsCard(viewModel: hudSettingsViewModel)
                .padding(.top, 8)

            Spacer()
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task {
            viewModel.refreshExtensionState()
        }
    }
    var StatusCard: some View {
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                )
        )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HUD Settings")
                        .font(.title3.weight(.semibold))
                    Text("Keep these in sync with the Safari pop-up.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("Synced", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.15))
                    )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("HUD Layout")
                    .font(.headline)
                Picker("HUD Layout", selection: $viewModel.layout) {
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
                Text("HUD Theme")
                    .font(.headline)
                Picker("HUD Theme", selection: $viewModel.theme) {
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

            VStack(alignment: .leading, spacing: 12) {
                Text("HUD Delay")
                    .font(.headline)
                HStack {
                    Slider(value: $viewModel.hudDelay, in: 0...1000, step: 10)
                    Text("\(Int(viewModel.hudDelay)) ms")
                        .font(.footnote.monospacedDigit())
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
                Text("Delay before the HUD hides after releasing ⌥ during tab switching.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Enable/disable the extension from the Safari pop-up; all other settings stay synced here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.thinMaterial)
                )
        )
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
}
#endif
