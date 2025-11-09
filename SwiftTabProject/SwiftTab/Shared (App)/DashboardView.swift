#if os(macOS)
import SwiftUI
import AppKit

struct DashboardView: View {
    @ObservedObject var viewModel: MacOnboardingViewModel

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

            ComingSoonCard()
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

private struct ComingSoonCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "dial.medium.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.gray.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("HUD preferences are on the way")
                    .font(.headline)
                Text("You’ll be able to customize the overlay directly in this app soon. For now, manage shortcuts in Safari Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
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
