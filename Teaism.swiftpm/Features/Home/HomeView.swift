import SwiftUI

struct HomeView: View {
    private enum StartOverlayStep {
        case modeSelection
        case soloPreparation
        case pairPreparation
    }

    private let soloImageAssetNames = ["mode_solo", "mode_solo_blacktea", "mode_solo_coffee"]
    private let pairImageAssetNames = [
        "mode_pair_blacktea_cha",
        "mode_pair_cha_coffee",
        "mode_pair_coffee_blacktea",
        "mode_pair",
    ]
    private let modeCardImageAspectRatio: CGFloat = 4.0 / 3.0
    private let modeCardImageHeight: CGFloat = 164
    private let modeImageRotationInterval: TimeInterval = 2.0
    private let modeImageBlendDuration: TimeInterval = 0.45

    let onStart: (CeremonyMode) -> Void
    let onShowZenPhraseLibrary: () -> Void
    let onShowAboutApp: () -> Void
    let onHomeVideoStarted: () -> Void
    let homeVideoRestartToken: UUID?
    let shouldAutoplayHomeVideo: Bool
    @State private var overlayStep: StartOverlayStep?
    @State private var isOverlayVisible = false
    @State private var selectedMode: CeremonyMode = .pair

    init(
        onStart: @escaping (CeremonyMode) -> Void,
        onShowZenPhraseLibrary: @escaping () -> Void = {},
        onShowAboutApp: @escaping () -> Void = {},
        onHomeVideoStarted: @escaping () -> Void = {},
        homeVideoRestartToken: UUID? = nil,
        shouldAutoplayHomeVideo: Bool = true
    ) {
        self.onStart = onStart
        self.onShowZenPhraseLibrary = onShowZenPhraseLibrary
        self.onShowAboutApp = onShowAboutApp
        self.onHomeVideoStarted = onHomeVideoStarted
        self.homeVideoRestartToken = homeVideoRestartToken
        self.shouldAutoplayHomeVideo = shouldAutoplayHomeVideo
    }

    var body: some View {
        ZStack {
            ZStack {
                VideoBackgroundView(
                    videoURL: Bundle.main.url(forResource: "home", withExtension: "mov"),
                    placeholderImageName: "bg_intro",
                    onVideoStarted: onHomeVideoStarted,
                    shouldAutoplay: shouldAutoplayHomeVideo,
                    restartToken: homeVideoRestartToken
                )

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.1),
                        Color.black.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                VStack(spacing: 10) {
                    Text("Meet Teaism")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(radius: 5)
                        .shadow(radius: 5)

                    Text("Bring the Japanese spirit of Sado\nto your daily life.")
                        .font(.system(size: 24, weight: .medium, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.88))
                        .shadow(radius: 5)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 24)

                PrimaryActionButton(
                    title: "Start a Tea Session",
                    action: { present(step: .modeSelection) }
                )
                .frame(maxWidth: 420)

                HStack(spacing: 18) {
                    Button(action: onShowZenPhraseLibrary) {
                        Text("Zen Scrolls")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .buttonStyle(.plain)

                    Button(action: onShowAboutApp) {
                        Text("About this App")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            if let overlayStep {
                overlayBackground
                    .opacity(isOverlayVisible ? 1 : 0)

                startOverlayCard(for: overlayStep)
                    .padding(24)
                    .opacity(isOverlayVisible ? 1 : 0)
                    .scaleEffect(isOverlayVisible ? 1 : 0.94)
                    .offset(y: isOverlayVisible ? 0 : 8)
            }
        }
    }

    private var overlayBackground: some View {
        Color.black.opacity(0.55)
            .ignoresSafeArea()
            .onTapGesture {
                dismissOverlay()
            }
    }

    @ViewBuilder
    private func startOverlayCard(for step: StartOverlayStep) -> some View {
        switch step {
        case .modeSelection:
            overlayContainer(title: "Choose your session", showsClose: true) {
                VStack(spacing: 18) {
                    Text("""
                    Bring Teaism into your usual tea time or coffee break.
                    Prepare drinks for everyone and begin in a calm place.
                    """)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.88))

                    HStack(spacing: 12) {
                        modeSelectionCard(
                            title: "Solo Session",
                            summary: "A mode for centering yourself through tea practice.",
                            points: [
                                "Choose keywords that match your current state and discover guidance.",
                                "Create a quiet pause in a busy day.",
                                "Spend time facing yourself with care.",
                            ],
                            imageAssetNames: soloImageAssetNames,
                            isSelected: selectedMode == .solo,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMode = .solo
                                }
                            }
                        )

                        modeSelectionCard(
                            title: "Pair Session",
                            summary: "A mode for creating shared Teaism time and deepening connection.",
                            points: [
                                "Take host and guest roles and practice the spirit of tea.",
                                "Express care for each other through mindful actions.",
                                "Deepen one-gathering experience through shared ritual and dialogue.",
                            ],
                            imageAssetNames: pairImageAssetNames,
                            isRecommended: true,
                            isSelected: selectedMode == .pair,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMode = .pair
                                }
                            }
                        )
                    }
                    .padding(.vertical, 2)

                    PrimaryActionButton(
                        title: selectedMode == .solo ? "Continue Solo" : "Continue as Pair",
                        action: { present(step: selectedMode == .solo ? .soloPreparation : .pairPreparation) }
                    )
                    .frame(maxWidth: 430)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        case .soloPreparation:
            overlayContainer(title: "Prepare for Solo Session") {
                VStack(spacing: 16) {
                    preparationIllustration(
                        imageAssetNames: soloImageAssetNames
                    )

                    Text("Find a calm place, keep your iPad and drink nearby, and begin.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))

                    PrimaryActionButton(
                        title: "Start",
                        action: { startCeremony(mode: .solo) }
                    )
                    .frame(maxWidth: 430)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        case .pairPreparation:
            overlayContainer(title: "Prepare for Pair Session") {
                VStack(spacing: 16) {
                    preparationIllustration(
                        imageAssetNames: pairImageAssetNames
                    )

                    Text("""
                        Find a calm place and keep your iPad and drinks nearby.
                        Sit with the host on the left and the guest on the right.
                        """)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))

                    PrimaryActionButton(
                        title: "Start",
                        action: { startCeremony(mode: .pair) }
                    )
                    .frame(maxWidth: 430)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private func modeSelectionCard(
        title: String,
        summary: String,
        points: [String],
        imageAssetNames: [String],
        isRecommended: Bool = false,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                if isRecommended {
                    Text("Recommended")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.brown)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white, in: Capsule())
                }

                Spacer()
            }

            RotatingImageAssetView(
                imageAssetNames: imageAssetNames,
                aspectRatio: modeCardImageAspectRatio,
                rotationInterval: modeImageRotationInterval,
                blendDuration: modeImageBlendDuration
            )
            .frame(width: modeCardImageHeight * modeCardImageAspectRatio, height: modeCardImageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)

            Text(summary)
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Label(point, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 402, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isSelected ? Color.brown.opacity(0.95) : (isRecommended ? Color.white.opacity(0.38) : Color.white.opacity(0.2)),
                            lineWidth: isSelected ? 2.6 : 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: action)
    }

    private func preparationIllustration(imageAssetNames: [String]) -> some View {
        RotatingImageAssetView(
            imageAssetNames: imageAssetNames,
            aspectRatio: modeCardImageAspectRatio,
            rotationInterval: modeImageRotationInterval,
            blendDuration: modeImageBlendDuration
        )
        .frame(maxWidth: 520)
        .aspectRatio(modeCardImageAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }

    private func overlayContainer<Content: View>(
        title: String,
        showsClose: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 18) {
            if showsClose {
                HStack {
                    Text(title)
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { present(step: .modeSelection) }) {
                        Label("Back", systemImage: "chevron.backward")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)

                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: 740)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.black.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func present(step: StartOverlayStep) {
        if overlayStep == nil {
            overlayStep = step
            isOverlayVisible = false
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.28)) {
                    isOverlayVisible = true
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                overlayStep = step
            }
        }
    }

    private func dismissOverlay(after completion: (() -> Void)? = nil) {
        guard overlayStep != nil else {
            completion?()
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            isOverlayVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard !isOverlayVisible else { return }
            overlayStep = nil
            completion?()
        }
    }

    private func startCeremony(mode: CeremonyMode) {
        dismissOverlay {
            onStart(mode)
        }
    }
}

#Preview {
    HomeView(onStart: { _ in })
}
