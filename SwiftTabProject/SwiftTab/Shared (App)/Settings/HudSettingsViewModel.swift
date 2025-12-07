#if os(macOS)
import Foundation
import Combine

@MainActor
final class HudSettingsViewModel: ObservableObject {
    @Published var hudDelay: Double
    @Published var layout: HudLayoutMode
    @Published var theme: HudThemeMode
    @Published var goToLastTabOnClose: Bool
    @Published var closeShortcutKey: String
    @Published var switchShortcut: ShortcutSetting
    @Published var searchShortcut: ShortcutSetting
    @Published var searchWeights: SearchWeights

    private var cancellables: Set<AnyCancellable> = []
    private var enabled: Bool
    private var isUpdatingFromStore = false

    private let store: HudSettingsStore

    init(store: HudSettingsStore) {
        self.store = store
        let settings = store.load()
        hudDelay = Double(settings.hudDelay)
        layout = settings.layout
        theme = settings.theme
        enabled = settings.enabled
        goToLastTabOnClose = settings.goToLastTabOnClose
        closeShortcutKey = settings.closeShortcutKey
        switchShortcut = settings.switchShortcut
        searchShortcut = settings.searchShortcut
        searchWeights = settings.searchWeights

        bindStore()
        bindPersist()
    }
    
    convenience init() {
        self.init(store: .shared)
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
        Publishers.CombineLatest4(
            Publishers.CombineLatest4($hudDelay, $layout, $theme, $goToLastTabOnClose),
            Publishers.CombineLatest($switchShortcut, $searchShortcut),
            $searchWeights,
            $closeShortcutKey
        )
            .receive(on: RunLoop.main)
            .dropFirst()
            .debounce(for: .milliseconds(1000), scheduler: RunLoop.main)
            .sink { [weak self] primary, shortcuts, weights, closeKey in
                let (delay, layout, theme, goToLastTabOnClose) = primary
                let (switchShortcut, searchShortcut) = shortcuts
                self?.persist(
                    delay: delay,
                    layout: layout,
                    theme: theme,
                    goToLastTabOnClose: goToLastTabOnClose,
                    switchShortcut: switchShortcut,
                    searchShortcut: searchShortcut,
                    searchWeights: weights,
                    closeShortcutKey: closeKey
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
        closeShortcutKey = latest.closeShortcutKey
        switchShortcut = latest.switchShortcut
        searchShortcut = latest.searchShortcut
        searchWeights = latest.searchWeights
        isUpdatingFromStore = false
    }

    private func persist(
        delay: Double,
        layout: HudLayoutMode,
        theme: HudThemeMode,
        goToLastTabOnClose: Bool,
        switchShortcut: ShortcutSetting,
        searchShortcut: ShortcutSetting,
        searchWeights: SearchWeights,
        closeShortcutKey: String
    ) {
        guard !isUpdatingFromStore else { return }
        let validation = validateShortcuts(switchShortcut: switchShortcut, closeShortcutKey: closeShortcutKey, searchShortcut: searchShortcut)
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
            closeShortcutKey: resolveCloseShortcutKey(
                closeShortcutKey,
                switchShortcut: switchShortcut,
                searchShortcut: searchShortcut,
                fallback: HudSettingsDefaults.defaultCloseShortcutKey
            ),
            switchShortcut: switchShortcut,
            searchShortcut: searchShortcut,
            searchWeights: searchWeights
        )
        store.save(next)
    }
}
#endif
