#if os(macOS)
import Foundation
import Combine
import SafariServices

@MainActor
final class MacOnboardingViewModel: ObservableObject {

    enum Stage: Equatable {
        case welcome
        case tutorial
        case dashboard
    }

    enum ExtensionState: Equatable {
        case unknown
        case enabled
        case disabled
        case error(message: String)
    }

    @Published var stage: Stage = .welcome
    @Published private(set) var extensionState: ExtensionState = .unknown
    @Published var isCheckingExtensionState = false
    @Published var isOpeningPreferences = false

    private let extensionIdentifier = "com.holmns.swifttab.Extension"
    private let userDefaults: UserDefaults
    private let hasLaunchedKey = "com.holmns.swifttab.hasLaunched"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let hasLaunched = userDefaults.bool(forKey: hasLaunchedKey)
        stage = hasLaunched ? .welcome : .welcome
        userDefaults.set(true, forKey: hasLaunchedKey)
    }

    func advanceFromWelcome() {
        guard stage == .welcome else { return }
        stage = .tutorial
    }

    func returnToWelcome() {
        stage = .welcome
    }

    func finishTutorial() {
        stage = .dashboard
        refreshExtensionState()
    }

    func refreshExtensionState() {
        isCheckingExtensionState = true
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionIdentifier) { [weak self] state, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isCheckingExtensionState = false

                if let error {
                    self.extensionState = .error(message: error.localizedDescription)
                } else if let state {
                    self.extensionState = state.isEnabled ? .enabled : .disabled
                } else {
                    self.extensionState = .unknown
                }
            }
        }
    }

    func openSafariPreferences(completion: (() -> Void)? = nil) {
        guard !isOpeningPreferences else { return }

        isOpeningPreferences = true
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionIdentifier) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isOpeningPreferences = false

                if let error {
                    self.extensionState = .error(message: error.localizedDescription)
                } else {
                    completion?()
                }
            }
        }
    }
}
#endif
