#if os(macOS)
import SwiftUI

struct TutorialView: View {
    let onBack: () -> Void
    let onFinish: () -> Void
    var onOpenSafari: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "safari")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)

            Text("Turn On the Extension")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 16)

            Text("SwiftTab runs as a Safari extension. Enable it once and it works in every window.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 20) {
                SetupStep(
                    number: 1,
                    title: "Open Safari Settings",
                    detail: "Use the button below, or choose Safari → Settings → Extensions."
                )
                SetupStep(
                    number: 2,
                    title: "Turn on SwiftTab",
                    detail: "Select the checkbox next to SwiftTab and approve the permission prompt."
                )
                SetupStep(
                    number: 3,
                    title: "Try it",
                    detail: "In Safari, press ⌥ Tab to switch to your previous tab."
                )
            }
            .frame(maxWidth: 420)
            .padding(.top, 40)

            if let onOpenSafari {
                Button("Open Safari Settings…", action: onOpenSafari)
                    .glassButtonStyle()
                    .padding(.top, 28)
            }

            Spacer()

            HStack {
                Button("Back", action: onBack)
                    .glassButtonStyle()

                Spacer()

                Button(action: onFinish) {
                    Text("Continue")
                        .frame(minWidth: 160)
                }
                .glassProminentButtonStyle()
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.quaternary.opacity(0.5)))

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

#Preview("TutorialView") {
    TutorialView(onBack: {}, onFinish: {}, onOpenSafari: {})
        .frame(width: 760, height: 560)
}
#endif
