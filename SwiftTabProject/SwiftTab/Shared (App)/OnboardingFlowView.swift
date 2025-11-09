#if os(macOS)
import SwiftUI
import AppKit
import Foundation

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: MacOnboardingViewModel

    var body: some View {
        ZStack {
            switch viewModel.stage {
            case .welcome:
                WelcomeScreen(onContinue: viewModel.advanceFromWelcome)
            case .tutorial:
                TutorialView(
                    onBack: viewModel.returnToWelcome,
                    onFinish: viewModel.finishTutorial
                )
            case .dashboard:
                DashboardView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.stage)
        .frame(minWidth: 1257, minHeight: 768)
    }
}

#Preview("Onboarding") {
    let defaults = UserDefaults(suiteName: "com.holmns.swifttab.preview")!
    defaults.removePersistentDomain(forName: "com.holmns.swifttab.preview")
    return OnboardingFlowView(viewModel: MacOnboardingViewModel(userDefaults: defaults))
}
#endif
