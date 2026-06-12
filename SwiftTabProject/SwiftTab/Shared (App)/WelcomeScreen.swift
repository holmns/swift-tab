#if os(macOS)
import SwiftUI

struct WelcomeScreen: View {
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("LargeIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)

            Text("Welcome to SwiftTab")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 16)

            Text("Switch Safari tabs in the order you use them.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "rectangle.on.rectangle",
                    title: "Most Recent First",
                    detail: "Cycle through tabs in the order you last used them, like ⌘ Tab for apps."
                )
                FeatureRow(
                    icon: "magnifyingglass",
                    title: "Search Your Tabs",
                    detail: "Open a searchable list of every tab and jump straight to it."
                )
                FeatureRow(
                    icon: "keyboard",
                    title: "Your Shortcuts",
                    detail: "Choose the keys that fit the way you work."
                )
            }
            .frame(maxWidth: 420)
            .padding(.top, 40)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .frame(minWidth: 160)
            }
            .glassProminentButtonStyle()
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                appeared = true
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("WelcomeView") {
    WelcomeScreen(onContinue: {})
        .frame(width: 760, height: 560)
}
#endif
