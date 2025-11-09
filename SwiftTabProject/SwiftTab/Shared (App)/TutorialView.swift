#if os(macOS)
import SwiftUI
import AppKit

struct TutorialView: View {
    let onBack: () -> Void
    let onFinish: () -> Void

    private let slides = TutorialSlide.sample
    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tutorial")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Get set up in Safari")
                        .font(.system(size: 30, weight: .bold))
                }
                Spacer()
                Button("Back to Welcome", action: onBack)
            }

            if !slides.isEmpty {
                TutorialSlideCard(slide: slides[currentIndex])
                    .id(slides[currentIndex].id)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .animation(.easeInOut(duration: 0.2), value: slides[currentIndex].id)
            }

            HStack(alignment: .bottom, spacing: 16) {
                PageIndicator(count: slides.count, currentIndex: $currentIndex)
                Spacer()
                Button(action: advance) {
                    Text(currentIndex == slides.count - 1 ? "Open Dashboard" : "Next")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 20)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func advance() {
        guard !slides.isEmpty else {
            onFinish()
            return
        }

        if currentIndex < slides.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentIndex += 1
            }
        } else {
            onFinish()
        }
    }
}

private struct TutorialSlideCard: View {
    let slide: TutorialSlide

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: slide.systemImage)
                    .font(.system(size: 28))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [
                                slide.accent.opacity(0.9),
                                slide.accent
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(slide.title)
                        .font(.title2.weight(.semibold))
                    Text(slide.message)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(slide.bullets, id: \.self) { bullet in
                    Label {
                        Text(bullet)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(slide.accent)
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .textBackgroundColor).opacity(0.32),
                            Color(nsColor: .textBackgroundColor).opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.08))
                )
        )
    }
}

struct PageIndicator: View {
    let count: Int
    @Binding var currentIndex: Int
    @State private var hoveredIndex: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(
                        width: index == currentIndex ? 32 : index == hoveredIndex ? 28 : 16,
                        height: hoveredIndex == index ? 12 : 10
                    )
                    .onHover { hovering in
                        hoveredIndex = hovering ? index : nil
                    }
                    .onTapGesture {
                        withAnimation {
                            currentIndex = index
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: hoveredIndex)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
    }
}

private struct TutorialSlide: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let systemImage: String
    let accent: Color
    let bullets: [String]

    static let sample: [TutorialSlide] = [
        .init(
            title: "Enable the extension",
            message: "Open Safari → Settings (⌘,) → Extensions → SwiftTab. Toggle it on and grant permission.",
            systemImage: "switch.2",
            accent: Color(red: 0.88, green: 0.35, blue: 0.47),
            bullets: [
                "Launch Safari Settings from the dashboard",
                "Check the SwiftTab box",
                "Approve the permission prompt"
            ]
        ),
        .init(
            title: "Learn the shortcut",
            message: "Use ⌥ + Tab to move forward and ⌥ + ⇧ + Tab to go backward through recent tabs.",
            systemImage: "keyboard.badge.ellipsis",
            accent: Color(red: 0.33, green: 0.49, blue: 0.93),
            bullets: [
                "Tap once to switch instantly",
                "Hold ⌥ to keep the HUD visible",
                "Release ⌥ to land on the highlighted tab"
            ]
        ),
        .init(
            title: "Search HUD",
            message: "Assign a shortcut in Safari Settings → Extensions → SwiftTab → Shortcuts to open the search HUD.",
            systemImage: "magnifyingglass.circle",
            accent: Color(red: 0.24, green: 0.7, blue: 0.56),
            bullets: [
                "Suggested shortcut: ⌘E",
                "Type to fuzzy-search tabs",
                "Press Esc or your shortcut again to dismiss"
            ]
        )
    ]
}

#Preview("TutorialView") {
    let viewModel = MacOnboardingViewModel()
    
    TutorialView(onBack: viewModel.returnToWelcome, onFinish: viewModel.advanceFromWelcome)
}
#endif
