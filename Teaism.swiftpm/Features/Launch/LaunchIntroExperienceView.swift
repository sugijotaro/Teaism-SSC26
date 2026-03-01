import SwiftUI

private enum LaunchIntroStep: Equatable {
    case quote
    case sadoMessage
    case invitation
}

struct LaunchIntroExperienceView: View {
    let onDoorOpeningStarted: () -> Void
    let onFinished: () -> Void

    @State private var introSplitProgress: CGFloat = 0
    @State private var introStep: LaunchIntroStep = .quote
    @State private var introContentOpacity = 0.0
    @State private var isNextButtonVisible = false
    @State private var isAdvancingIntro = false
    @State private var hasStartedLaunchSequence = false

    var body: some View {
        LaunchOverlaySplitView(
            introStep: introStep,
            introContentOpacity: introContentOpacity,
            isNextButtonVisible: isNextButtonVisible,
            isAdvancingIntro: isAdvancingIntro,
            splitProgress: splitProgressForOpen(rawProgress: introSplitProgress),
            onNext: advanceIntro,
            onBack: retreatIntro
        )
        .onAppear {
            startLaunchSequenceIfNeeded()
        }
    }

    private func startLaunchSequenceIfNeeded() {
        guard !hasStartedLaunchSequence else { return }
        hasStartedLaunchSequence = true

        withAnimation(.easeIn(duration: 1.0)) {
            introContentOpacity = 1
            isNextButtonVisible = true
        }
    }

    private func advanceIntro() {
        guard !isAdvancingIntro else { return }

        switch introStep {
        case .quote:
            revealSadoMessage()
        case .sadoMessage:
            transitionIntro(to: .invitation)
        case .invitation:
            completeIntro()
        }
    }

    private func retreatIntro() {
        guard !isAdvancingIntro else { return }

        switch introStep {
        case .quote:
            return
        case .sadoMessage:
            hideSadoMessage()
        case .invitation:
            transitionIntro(to: .sadoMessage)
        }
    }

    private func revealSadoMessage() {
        isAdvancingIntro = true

        withAnimation(.easeInOut(duration: 0.8)) {
            introStep = .sadoMessage
        }

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            await MainActor.run {
                isAdvancingIntro = false
            }
        }
    }

    private func hideSadoMessage() {
        isAdvancingIntro = true

        withAnimation(.easeInOut(duration: 0.8)) {
            introStep = .quote
        }

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            await MainActor.run {
                isAdvancingIntro = false
            }
        }
    }

    private func transitionIntro(to nextStep: LaunchIntroStep) {
        isAdvancingIntro = true

        withAnimation(.easeOut(duration: 0.25)) {
            introContentOpacity = 0
        }

        Task {
            try? await Task.sleep(for: .milliseconds(250))
            await MainActor.run {
                introStep = nextStep
                withAnimation(.easeIn(duration: 0.35)) {
                    introContentOpacity = 1
                }
            }
            try? await Task.sleep(for: .milliseconds(350))
            await MainActor.run {
                isAdvancingIntro = false
            }
        }
    }

    private func completeIntro() {
        isAdvancingIntro = true
        isNextButtonVisible = false

        withAnimation(.easeOut(duration: 0.3)) {
            introContentOpacity = 0
        }

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run {
                withAnimation(.linear(duration: 5.0)) {
                    introSplitProgress = 1
                }
                onDoorOpeningStarted()
            }
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                onFinished()
            }
        }
    }

    private func splitProgressForOpen(rawProgress: CGFloat) -> CGFloat {
        let t = min(max(Double(rawProgress), 0), 1)
        let accelPortion = 0.60
        let decelPortion = 0.25
        let cruisePortion = 1.0 - accelPortion - decelPortion
        let cruiseVelocity = 1.0 / (cruisePortion + (accelPortion + decelPortion) / 2.0)

        if t <= accelPortion {
            let progress = 0.5 * cruiseVelocity / accelPortion * t * t
            return CGFloat(progress)
        }

        let progressAtAccelEnd = 0.5 * cruiseVelocity * accelPortion
        if t <= accelPortion + cruisePortion {
            let progress = progressAtAccelEnd + cruiseVelocity * (t - accelPortion)
            return CGFloat(progress)
        }

        let decelStart = accelPortion + cruisePortion
        let progressAtDecelStart = progressAtAccelEnd + cruiseVelocity * cruisePortion
        let u = t - decelStart
        let progress = progressAtDecelStart + cruiseVelocity * (u - (u * u) / (2.0 * decelPortion))
        return CGFloat(min(max(progress, 0), 1))
    }
}

private struct LaunchOverlaySplitView: View {
    let introStep: LaunchIntroStep
    let introContentOpacity: Double
    let isNextButtonVisible: Bool
    let isAdvancingIntro: Bool
    let splitProgress: CGFloat
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let halfWidth = proxy.size.width / 2
            let panelOffset = halfWidth * splitProgress

            ZStack {
                Color.clear
                    .contentShape(Rectangle())

                LaunchOverlayView(
                    introStep: introStep,
                    introContentOpacity: introContentOpacity,
                    isNextButtonVisible: isNextButtonVisible,
                    isAdvancingIntro: isAdvancingIntro,
                    onNext: onNext
                )
                .mask(
                    Rectangle()
                        .frame(width: halfWidth)
                        .offset(x: -halfWidth / 2)
                )
                .offset(x: -panelOffset)
                .shadow(color: .black.opacity(0.18 * splitProgress), radius: 10, x: 6, y: 0)

                LaunchOverlayView(
                    introStep: introStep,
                    introContentOpacity: introContentOpacity,
                    isNextButtonVisible: isNextButtonVisible,
                    isAdvancingIntro: isAdvancingIntro,
                    onNext: onNext
                )
                .mask(
                    Rectangle()
                        .frame(width: halfWidth)
                        .offset(x: halfWidth / 2)
                )
                .offset(x: panelOffset)
                .shadow(color: .black.opacity(0.18 * splitProgress), radius: 10, x: -6, y: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let horizontalDistance = value.translation.width
                        let verticalDistance = abs(value.translation.height)

                        guard horizontalDistance > 60, verticalDistance < 80 else { return }
                        onBack()
                    }
            )
        }
        .ignoresSafeArea()
    }
}

private struct LaunchOverlayView: View {
    let introStep: LaunchIntroStep
    let introContentOpacity: Double
    let isNextButtonVisible: Bool
    let isAdvancingIntro: Bool
    let onNext: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 24) {
                    introTextContent
                }
                .padding(.horizontal, 24)
                .opacity(introContentOpacity)

                Spacer()
            }
            .frame(maxWidth: .infinity)

            if isNextButtonVisible {
                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.black.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isAdvancingIntro)
                .opacity(isAdvancingIntro ? 0.5 : 1)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }

    @ViewBuilder
    private var introTextContent: some View {
        switch introStep {
        case .quote, .sadoMessage:
            VStack(spacing: 26) {
                teaImage
                quoteText

                if introStep == .sadoMessage {
                    sadoMessageText
                }
            }

        case .invitation:
            Text("This iPad app brings the spirit of Sado, Teaism,\ninto your everyday tea time or coffee break.\n\nPrepare your favorite drink, invite a friend,\nand experience this app together.")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
        }
    }

    private var quoteText: some View {
        VStack(spacing: 16) {
            Text("""
                 Chanoyu is nothing more than
                 boiling water, making tea and drinking it.
                """)
            .font(.system(size: 32, weight: .regular, design: .serif))
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.black)

            Text("Sen no Rikyu (1522-1591)")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(.black.opacity(0.9))
        }
    }

    private var sadoMessageText: some View {
        Text("As Sen no Rikyu taught through Sado,\none bowl of tea is a way to cherish harmony with others.")
            .font(.system(size: 24, weight: .regular, design: .serif))
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.black)
    }

    private var teaImage: some View {
        Image("tea")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 260)
            .clipShape(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
    }
}

#Preview("Launch Overlay / Quote") {
    LaunchOverlayView(
        introStep: .quote,
        introContentOpacity: 1,
        isNextButtonVisible: true,
        isAdvancingIntro: false,
        onNext: {}
    )
}

#Preview("Launch Overlay / Sado Message") {
    LaunchOverlayView(
        introStep: .sadoMessage,
        introContentOpacity: 1,
        isNextButtonVisible: true,
        isAdvancingIntro: false,
        onNext: {}
    )
}

#Preview("Launch Overlay / Invitation") {
    LaunchOverlayView(
        introStep: .invitation,
        introContentOpacity: 1,
        isNextButtonVisible: true,
        isAdvancingIntro: false,
        onNext: {}
    )
}
