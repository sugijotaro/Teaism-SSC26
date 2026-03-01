import SwiftUI

struct CeremonyFlowView: View {
    private enum EntrySequencePhase {
        case playingVideo
        case chanomaOnly
        case ceremonyUI
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var session: CeremonySessionViewModel
    let onFinish: () -> Void
    let onEntryVideoStarted: () -> Void

    @State private var isPreparingZenScroll = false
    @State private var isExitConfirmationPresented = false
    @State private var isCommentaryVisible = false
    @State private var entrySequencePhase: EntrySequencePhase = .playingVideo
    @State private var chanomaOverlayOpacity: Double = 0
    @State private var hasPreparedEntrySequence = false
    @State private var hasNotifiedEntryVideoStarted = false
    @State private var revealCeremonyUITask: Task<Void, Never>?
    @State private var delayedVoicePlaybackTask: Task<Void, Never>?
    @State private var isCommentaryHintVisible = false
    @State private var hasShownCommentaryHint = false

    private let stepChangeAnimation = Animation.spring(response: 0.58, dampingFraction: 0.86, blendDuration: 0.2)
    private let chanomaCrossfadeDuration = 1.0
    private let ceremonyUIRevealDelayNanoseconds: UInt64 = 500_000_000
    private let voicePlaybackDelayNanoseconds: UInt64 = 500_000_000
    private let kissaTokonomaPlacement = ImageRegionPlacement(
        imagePixelSize: CGSize(width: 2400, height: 1792),
        targetRegion: CGRect(x: 668, y: 434, width: 446, height: 766)
    )

    init(
        session: CeremonySessionViewModel,
        onFinish: @escaping () -> Void,
        onEntryVideoStarted: @escaping () -> Void = {}
    ) {
        self.session = session
        self.onFinish = onFinish
        self.onEntryVideoStarted = onEntryVideoStarted
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if showsEntryVideo {
                VideoBackgroundView(
                    videoURL: enterVideoURL,
                    placeholderImageName: "bg_chanoma",
                    onVideoStarted: notifyEntryVideoStartedIfNeeded,
                    onVideoFinished: handleEntryVideoFinished,
                    onVideoNearEnd: handleEntryVideoNearEnd,
                    nearEndThreshold: 1,
                    shouldAutoplay: true,
                    shouldLoop: false
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            if showsChanomaOverlayLayer {
                TeaRoomBackground(scene: .chanoma)
                    .opacity(chanomaOverlayOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if isCeremonyUIVisible && showsPersistentZenScrollOverlay {
                GeometryReader { proxy in
                    persistentZenScroll
                        .position(kissaTokonomaPlacement.centerPoint(in: proxy.size))
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            if isCeremonyUIVisible {
                ceremonyContent
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if isCeremonyUIVisible {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: { isExitConfirmationPresented = true }) {
                            Label("Back to Home", systemImage: "house")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if canGoBack {
                            Button(action: goBack) {
                                Image(systemName: "arrowshape.turn.up.backward")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) {
                            if showsCommentaryToggle {
                                commentaryToggleView
                            }
                            voiceModeToggleView
                        }

                        if showsCommentaryToggle, isCommentaryHintVisible {
                            commentaryHintBubble
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
                .padding(.leading)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isCeremonyUIVisible {
                bottomPanel
            }
        }
        .task(id: session.step) {
            guard isCeremonyUIVisible else {
                isPreparingZenScroll = false
                return
            }

            guard session.step == .zenScroll else {
                isPreparingZenScroll = false
                return
            }

            isPreparingZenScroll = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            guard !Task.isCancelled, session.step == .zenScroll else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                isPreparingZenScroll = false
            }
        }
        .alert("Leave this session?", isPresented: $isExitConfirmationPresented) {
            Button("Back to Home", role: .destructive) {
                onFinish()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current session will end and you will return to the home screen.")
        }
        .onAppear(perform: prepareEntrySequence)
        .onChange(of: entrySequencePhase) { phase in
            guard phase == .ceremonyUI else { return }
            if !(session.step == .zenScroll && isPreparingZenScroll) {
                scheduleDelayedVoicePlayback()
            }
            if showsCommentaryToggle {
                showCommentaryHintIfNeeded()
            }
        }
        .onChange(of: session.step) { _ in
            if isCeremonyUIVisible, session.step != .zenScroll {
                scheduleDelayedVoicePlayback()
            }
            guard showsCommentaryToggle else {
                isCommentaryVisible = false
                isCommentaryHintVisible = false
                return
            }
        }
        .onChange(of: isPreparingZenScroll) { isPreparing in
            guard isCeremonyUIVisible else { return }
            guard session.step == .zenScroll else { return }
            guard !isPreparing else { return }
            scheduleDelayedVoicePlayback()
        }
        .onDisappear {
            revealCeremonyUITask?.cancel()
            revealCeremonyUITask = nil
            delayedVoicePlaybackTask?.cancel()
            delayedVoicePlaybackTask = nil
            session.stopCurrentStepVoicePlayback()
            isCommentaryHintVisible = false
            hasShownCommentaryHint = false
            hasPreparedEntrySequence = false
            hasNotifiedEntryVideoStarted = false
        }
    }

    private var ceremonyContent: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    animatedStageContent

                    Color.clear
                        .frame(height: 120)
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 18)
            }
            .scrollDisabled(isStageScrollLocked)
        }
    }

    private var enterVideoURL: URL? {
        Bundle.main.url(forResource: "enter", withExtension: "mov")
    }

    private var showsEntryVideo: Bool {
        entrySequencePhase == .playingVideo
    }

    private var showsChanomaOverlayLayer: Bool {
        entrySequencePhase != .ceremonyUI
    }

    private var isCeremonyUIVisible: Bool {
        entrySequencePhase == .ceremonyUI
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if !isCeremonyUIVisible {
            TeaRoomBackground(scene: .chanoma)
        } else {
            switch session.step {
            case .opening, .guestQuestion, .keywordSelection:
                TeaRoomBackground(scene: .chanoma)
            case .zenScroll:
                if isPreparingZenScroll {
                    TeaRoomBackground(scene: .tokonoma)
                } else {
                    TeaRoomBackground(scene: .tokonomaWithout)
                }
            case .zenPhraseMeaning, .hostServe, .guestReceive, .sharedSip, .closing, .soloBowlGesture, .soloJournal:
                TeaRoomBackground(scene: .kissa)
            }
        }
    }

    private func prepareEntrySequence() {
        guard !hasPreparedEntrySequence else { return }
        hasPreparedEntrySequence = true

        guard enterVideoURL != nil else {
            chanomaOverlayOpacity = 1
            entrySequencePhase = .ceremonyUI
            notifyEntryVideoStartedIfNeeded()
            return
        }

        chanomaOverlayOpacity = 0
        entrySequencePhase = .playingVideo
    }

    private func notifyEntryVideoStartedIfNeeded() {
        guard !hasNotifiedEntryVideoStarted else { return }
        hasNotifiedEntryVideoStarted = true
        onEntryVideoStarted()
    }

    private func handleEntryVideoNearEnd() {
        guard entrySequencePhase == .playingVideo, chanomaOverlayOpacity < 1 else { return }

        withAnimation(.easeInOut(duration: chanomaCrossfadeDuration)) {
            chanomaOverlayOpacity = 1
        }
    }

    private func handleEntryVideoFinished() {
        guard entrySequencePhase == .playingVideo else { return }

        entrySequencePhase = .chanomaOnly
        if chanomaOverlayOpacity < 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                chanomaOverlayOpacity = 1
            }
        }

        revealCeremonyUITask?.cancel()
        revealCeremonyUITask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: ceremonyUIRevealDelayNanoseconds)
            guard !Task.isCancelled, entrySequencePhase == .chanomaOnly else { return }

            withAnimation(.easeInOut(duration: 0.30)) {
                entrySequencePhase = .ceremonyUI
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(session.mode.title)
                .font(.system(size: 34, weight: .bold, design: .serif))
            Text(session.mode.subtitle)
                .font(.subheadline)
                .opacity(0.86)

            HStack(spacing: 8) {
                ForEach(session.steps.indices, id: \.self) { index in
                    Circle()
                        .fill(index <= session.currentStepIndex ? Color.white.opacity(0.95) : Color.white.opacity(0.24))
                        .frame(
                            width: index == session.currentStepIndex ? 11 : 8,
                            height: index == session.currentStepIndex ? 11 : 8
                        )
                        .scaleEffect(index == session.currentStepIndex ? 1.08 : 1)
                        .shadow(
                            color: .white.opacity(index == session.currentStepIndex ? 0.5 : 0),
                            radius: index == session.currentStepIndex ? 8 : 0
                        )
                }
            }
            .animation(.easeInOut(duration: 0.3), value: session.currentStepIndex)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var animatedStageContent: some View {
        ZStack {
            stageContent
                .id("stage-\(session.currentStepIndex)")
                .transition(stageTransition(for: session.currentStepContent.focusSide))
        }
        .animation(stepChangeAnimation, value: session.step)
    }

    @ViewBuilder
    private var stageContent: some View {
        switch session.step {
        case .keywordSelection:
            alignedStage(for: session.currentStepContent.focusSide) {
                VStack(alignment: session.isSoloMode ? .center : .leading, spacing: 16) {
                    sidePromptPanel()
                    KeywordSelectionView(
                        title: session.keywordPromptTitle,
                        keywords: session.availableKeywords,
                        selected: session.selectedKeywords,
                        isCentered: session.isSoloMode,
                        onToggle: session.toggleKeyword
                    )
                }
                .frame(maxWidth: 640)
            }
        case .zenScroll:
            alignedStage(for: session.currentStepContent.focusSide) {
                VStack(spacing: 16) {
                    if isPreparingZenScroll {
                        zenScrollLoadingView
                            .frame(maxWidth: 520)
                    } else {
                        zenScrollDisplayOnlyView
                            .frame(maxWidth: 520)
                        sidePromptPanel()
                            .frame(maxWidth: 640)
                            .padding(.top, 32)
                    }
                }
            }
        case .zenPhraseMeaning:
            alignedStage(for: session.currentStepContent.focusSide) {
                VStack(spacing: 16) {
                    sidePromptPanel()
                        .frame(maxWidth: 460)

                    ZenScrollView(
                        phrase: session.zenPhrase,
                        selectedKeywords: session.selectedKeywordTitles,
                        showsHangingScroll: false
                    )
                    .frame(maxWidth: 460)
                }
            }
        case .soloJournal:
            alignedStage(for: session.currentStepContent.focusSide) {
                VStack(spacing: 16) {
                    sidePromptPanel()
                        .frame(maxWidth: 640)
                }
            }
        default:
            alignedStage(for: session.currentStepContent.focusSide) {
                sidePromptPanel()
                    .frame(maxWidth: 640)
            }
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: 8) {
            actionButton
                .id("button-\(session.currentStepIndex)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
        }
        .frame(maxWidth: 920)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .animation(stepChangeAnimation, value: session.step)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func alignedStage<Content: View>(
        for focusSide: CeremonyStep.FocusSide,
        @ViewBuilder content: () -> Content
    ) -> some View {
        switch focusSide {
        case .leftHost:
            HStack(spacing: 0) {
                content()
                Spacer(minLength: 0)
            }
        case .rightGuest:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                content()
            }
        case .both:
            content()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func sidePromptPanel() -> some View {
        let alignment = textAlignment(for: session.currentStepContent.focusSide)

        return VStack(alignment: alignment.horizontal, spacing: 10) {
            if !session.isSoloMode {
                Text(session.currentStepContent.roleLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.14), in: Capsule())
                    .padding(.bottom, 8)
            }

            Text(session.currentStepContent.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(alignment.text)
                .foregroundStyle(.white)

            Text(session.currentStepContent.instruction)
                .font(.body)
                .lineSpacing(4)
                .multilineTextAlignment(alignment.text)
                .foregroundStyle(.white.opacity(0.86))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var commentaryToggleView: some View {
        Button(action: {
            hideCommentaryHint()
            withAnimation(.easeInOut(duration: 0.22)) {
                isCommentaryVisible.toggle()
            }
        }) {
            HStack(alignment: .top, spacing: 8) {
                Text("？")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isCommentaryVisible ? .black : .white)
                    .padding(.top, 1)

                if isCommentaryVisible {
                    Text(session.currentStepContent.commentary ?? "No commentary is available for this step.")
                        .font(.caption)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 34, minHeight: 34, alignment: .leading)
            .frame(
                maxWidth: isCommentaryVisible ? (horizontalSizeClass == .compact ? 250 : 320) : nil,
                alignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCommentaryVisible ? .white : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCommentaryVisible ? "Hide commentary" : "Show commentary")
    }

    private var voiceModeToggleView: some View {
        let showsVoiceModeLabel = !isCommentaryVisible

        return Button(action: {
            let willEnable = !session.isAutoVoiceModeEnabled
            withAnimation(.easeInOut(duration: 0.22)) {
                session.isAutoVoiceModeEnabled = willEnable
            }
            if willEnable, session.step == .zenScroll, isPreparingZenScroll {
                session.stopCurrentStepVoicePlayback()
            }
        }) {
            HStack(spacing: showsVoiceModeLabel ? 6 : 0) {
                Image(systemName: session.isAutoVoiceModeEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.caption.weight(.semibold))

                if showsVoiceModeLabel {
                    Text(session.isAutoVoiceModeEnabled ? "Voice On" : "Voice Off")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(session.isAutoVoiceModeEnabled ? .black : .white.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(session.isAutoVoiceModeEnabled ? .white : .white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.isAutoVoiceModeEnabled ? "Disable voice mode" : "Enable voice mode")
    }

    private var commentaryHintBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            SpeechTail()
                .fill(.black.opacity(0.58))
                .frame(width: 12, height: 6)
                .rotationEffect(.degrees(180))
                .padding(.leading, 13)
                .offset(y: 1)

            Text("Tap here for deeper guidance")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.black.opacity(0.58))
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hideCommentaryHint()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Dismiss commentary hint")
    }

    private func showCommentaryHintIfNeeded() {
        guard !hasShownCommentaryHint else { return }
        hasShownCommentaryHint = true

        withAnimation(.easeInOut(duration: 0.2)) {
            isCommentaryHintVisible = true
        }
    }

    private func hideCommentaryHint() {
        guard isCommentaryHintVisible else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isCommentaryHintVisible = false
        }
    }

    private func textAlignment(for focusSide: CeremonyStep.FocusSide) -> (horizontal: HorizontalAlignment, text: TextAlignment) {
        switch focusSide {
        case .leftHost:
            return (.leading, .leading)
        case .rightGuest:
            return (.trailing, .trailing)
        case .both:
            return (.center, .center)
        }
    }

    private func stageTransition(for focusSide: CeremonyStep.FocusSide) -> AnyTransition {
        let insertionEdge: Edge
        switch focusSide {
        case .leftHost:
            insertionEdge = .leading
        case .rightGuest:
            insertionEdge = .trailing
        case .both:
            insertionEdge = .bottom
        }

        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .opacity
        )
    }

    private var actionButton: some View {
        PrimaryActionButton(
            title: actionButtonTitle,
            subtitle: actionButtonSubtitle,
            isEnabled: canAdvance,
            action: advance
        )
        .frame(maxWidth: 460)
    }

    private var actionButtonTitle: String {
        if session.step == .zenScroll && isPreparingZenScroll {
            return "Selecting a Zen scroll..."
        }
        return session.currentStepContent.actionTitle
    }

    private var actionButtonSubtitle: String? {
        if session.step == .zenScroll && isPreparingZenScroll {
            return nil
        }
        return session.currentStepContent.actionSubtitle
    }

    private var canAdvance: Bool {
        session.canAdvanceBySessionState && !(session.step == .zenScroll && isPreparingZenScroll)
    }

    private var canGoBack: Bool {
        session.currentStepIndex > 0
    }

    private var isStageScrollLocked: Bool {
        session.step == .zenScroll
    }

    private var showsCommentaryToggle: Bool {
        session.currentStepContent.commentary != nil
    }

    private var showsPersistentZenScroll: Bool {
        session.showsPersistentZenScroll
    }

    private var showsPersistentZenScrollOverlay: Bool {
        guard showsPersistentZenScroll else { return false }
        if session.step == .zenPhraseMeaning {
            return horizontalSizeClass != .compact
        }
        return true
    }

    private var persistentZenScroll: some View {
        PersistentZenScrollOverlay(
            zenPhrase: session.zenPhrase
        )
    }

    private var zenScrollLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.15)

            Text(session.isSoloMode ? "Choosing a scroll based on your selected keywords..." : "Choosing a scroll based on the host's selected keywords...")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var zenScrollDisplayOnlyView: some View {
        ZenHangingScroll(
            zenPhrase: session.zenPhrase,
            width: 230
        )
    }

    private func advance() {
        if session.step == .closing || session.step == .soloJournal {
            onFinish()
        } else {
            if session.step == .keywordSelection {
                isPreparingZenScroll = true
            }
            withAnimation(stepChangeAnimation) {
                session.nextStep()
            }
        }
    }

    private func goBack() {
        withAnimation(stepChangeAnimation) {
            session.previousStep()
        }
    }

    private func scheduleDelayedVoicePlayback() {
        delayedVoicePlaybackTask?.cancel()
        delayedVoicePlaybackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: voicePlaybackDelayNanoseconds)
            guard !Task.isCancelled else { return }
            guard isCeremonyUIVisible else { return }
            session.playCurrentStepVoiceIfNeeded()
        }
    }
}

private struct PersistentZenScrollOverlay: View {
    let zenPhrase: ZenPhrase

    var body: some View {
        ZenHangingScroll(
            zenPhrase: zenPhrase,
            width: 84
        )
    }
}

private struct ImageRegionPlacement {
    let imagePixelSize: CGSize
    let targetRegion: CGRect

    private var normalizedCenter: CGPoint {
        CGPoint(
            x: targetRegion.midX / imagePixelSize.width,
            y: targetRegion.midY / imagePixelSize.height
        )
    }

    func centerPoint(in containerSize: CGSize) -> CGPoint {
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else {
            return CGPoint(x: containerSize.width * 0.5, y: containerSize.height * 0.5)
        }

        let scale = max(
            containerSize.width / imagePixelSize.width,
            containerSize.height / imagePixelSize.height
        )
        let renderedImageSize = CGSize(
            width: imagePixelSize.width * scale,
            height: imagePixelSize.height * scale
        )
        let renderedImageOrigin = CGPoint(
            x: (containerSize.width - renderedImageSize.width) * 0.5,
            y: (containerSize.height - renderedImageSize.height) * 0.5
        )
        let center = normalizedCenter

        return CGPoint(
            x: renderedImageOrigin.x + (renderedImageSize.width * center.x),
            y: renderedImageOrigin.y + (renderedImageSize.height * center.y)
        )
    }
}

private struct SpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    CeremonyFlowView(
        session: CeremonySessionViewModel(),
        onFinish: {}
    )
}

#Preview("Persistent Zen Scroll") {
    let previewPlacement = ImageRegionPlacement(
        imagePixelSize: CGSize(width: 2400, height: 1792),
        targetRegion: CGRect(x: 668, y: 434, width: 446, height: 766)
    )

    return ZStack(alignment: .center) {
        TeaRoomBackground(scene: .kissa)
        GeometryReader { proxy in
            PersistentZenScrollOverlay(
                zenPhrase: CeremonyCatalog.defaultPhrase
            )
            .position(previewPlacement.centerPoint(in: proxy.size))
        }
    }
}
