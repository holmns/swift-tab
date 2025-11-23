#if os(macOS)
import SwiftUI

struct WelcomeScreen: View {
    let onContinue: () -> Void
    private let features = FeatureHighlight.sample

    @State private var heroPhase: HeroAnimationPhase = .hidden
    @State private var textVisible = false
    @State private var contentVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HeroHeader(phase: heroPhase, textVisible: textVisible)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, heroPhase == .lifted ? 100 : 80)

            Group {
                HStack(spacing: 16) {
                    ForEach(features) { feature in
                        FeatureCard(feature: feature)
                    }
                }

                HStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("Get Started")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.brandPrimary))
                    }
                    .buttonStyle(.plain)

                    Text("MacOS 14+ recommended.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 40)
        }
        .padding(40)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: heroPhase == .lifted ? .top : .center
        )
        .background(Color.black)
        .onAppear{runHeroSequence()}
    }

    private func runHeroSequence() {
        guard heroPhase == .hidden else { return }

        withAnimation(.spring(duration: 5)) {
            heroPhase = .focus
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(duration: 3)) {
                textVisible = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85)) {
                heroPhase = .lifted
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(duration: 0.6)) {
                contentVisible = true
            }
        }
    }
}

private struct HeroHeader: View {
    let phase: HeroAnimationPhase
    let textVisible: Bool

    private let titleGradient = LinearGradient(
        colors: [
            Color.brandPrimary,
            Color.brandSecondary,
            Color.brandPrimary,
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 20) {
            Image("LargeIcon")
                .resizable()
                .frame(width: 140, height: 140)
                .opacity(phase == .hidden ? 0 : 1)
                .scaleEffect(phase == .focus ? 1.25 : 1.0)
                .offset(y: phase == .focus ? -20 : 0)
                .animation(.spring(duration: 0.8), value: phase)

            VStack(spacing: 8) {
                Text("Go through tabs, swiftly.")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(titleGradient)
                    .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 10)
                    .opacity(textVisible ? 1 : 0)
                    .offset(y: textVisible ? 0 : 20)

                Text("Let SwiftTab speed up the way you move through Safari.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .opacity(textVisible ? 0.95 : 0)
                    .offset(y: textVisible ? 0 : 20)
            }
        }
        .animation(.spring(duration: 0.6), value: textVisible)
    }
}

private enum HeroAnimationPhase {
    case hidden
    case focus
    case lifted
}

private struct FeatureCard: View {
    let feature: FeatureHighlight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(feature.title)
                    .font(.headline)
            } icon: {
                Image(systemName: feature.icon)
                    .symbolVariant(.fill)
            }
            Text(feature.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }
}

private struct FeatureHighlight: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String

    static let sample: [FeatureHighlight] = [
        .init(title: "MRU Switching", detail: "Cycle through tabs in the order you last used them.", icon: "rectangle.on.rectangle"),
        .init(title: "Searchable HUD", detail: "Pop open a searchable list of tabs with your shortcut.", icon: "magnifyingglass"),
        .init(title: "Safari Native", detail: "Ships as a signed Safari app extension.", icon: "lock.shield")
    ]
}

#Preview("WelcomeView") {
    let viewModel = MacOnboardingViewModel()
    WelcomeScreen(onContinue: viewModel.advanceFromWelcome)
        .frame(width: 1257, height: 768)
}
#endif
