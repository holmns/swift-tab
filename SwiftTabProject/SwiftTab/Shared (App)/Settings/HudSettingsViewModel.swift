#if os(macOS)
import Foundation
import Combine

@MainActor
final class HudSettingsViewModel: ObservableObject {
    @Published var hudDelay: Double
    @Published var layout: HudLayoutMode
    @Published var theme: HudThemeMode
    @Published var goToLastTabOnClose: Bool
    @Published var switchShortcut: ShortcutSetting
    @Published var searchShortcut: ShortcutSetting

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
        goToLastTabOnClose = settings.goToLastTabOnClose
        switchShortcut = settings.switchShortcut
        searchShortcut = settings.searchShortcut

        bindStore()
        bindPersist()
    }

    private func bindStore() {
        DistributedNotificationCenter.default()
            .publisher(for: HudSettingsDefaults.changedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Defer to the next run loop tick to avoid publishing during SwiftUI view updates.
                DispatchQueue.main.async { [weak self] in
                    self?.refreshFromStore()
                }
            }
            .store(in: &cancellables)
    }

    private func bindPersist() {
        Publishers.CombineLatest(
            Publishers.CombineLatest4($hudDelay, $layout, $theme, $goToLastTabOnClose),
            Publishers.CombineLatest($switchShortcut, $searchShortcut)
        )
            .receive(on: RunLoop.main)
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] primary, shortcuts in
                let (delay, layout, theme, goToLastTabOnClose) = primary
                let (switchShortcut, searchShortcut) = shortcuts
                self?.persist(
                    delay: delay,
                    layout: layout,
                    theme: theme,
                    goToLastTabOnClose: goToLastTabOnClose,
                    switchShortcut: switchShortcut,
                    searchShortcut: searchShortcut
                )
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
        goToLastTabOnClose = latest.goToLastTabOnClose
        switchShortcut = latest.switchShortcut
        searchShortcut = latest.searchShortcut
        isUpdatingFromStore = false
    }

    private func persist(
        delay: Double,
        layout: HudLayoutMode,
        theme: HudThemeMode,
        goToLastTabOnClose: Bool,
        switchShortcut: ShortcutSetting,
        searchShortcut: ShortcutSetting
    ) {
        guard !isUpdatingFromStore else { return }
        let validation = validateShortcuts(switchShortcut: switchShortcut, searchShortcut: searchShortcut)
        guard validation.errors.isEmpty else {
            refreshFromStore()
            return
        }
        let clampedDelay = max(0, min(1000, Int(delay.rounded())))
        let next = HudSettingsState(
            enabled: enabled,
            hudDelay: clampedDelay,
            layout: layout,
            theme: theme,
            goToLastTabOnClose: goToLastTabOnClose,
            switchShortcut: switchShortcut,
            searchShortcut: searchShortcut
        )
        store.save(next)
    }
}
#endif
