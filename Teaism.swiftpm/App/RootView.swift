import SwiftUI

struct RootView: View {
    private enum Screen {
        case home
        case aboutApp
        case ceremony
        case zenPhraseLibrary
    }

    @StateObject private var session = CeremonySessionViewModel()
    private let audioManager = AudioManager.shared
    @State private var screen: Screen = .home
    @State private var isLaunchIntroPresented = true
    @State private var hasBootstrappedAudio = false
    @State private var hasStartedHomeBGM = false
    @State private var shouldAutoplayHomeVideo = false
    @State private var homeVideoRestartToken: UUID?
    @State private var transitionOverlayOpacity = 0.0
    @State private var isCeremonyTransitionRunning = false
    @State private var hasCeremonyEntryVideoStarted = false
    @State private var ceremonyTransitionTask: Task<Void, Never>?
    @State private var zenPhraseLibraryBackDestination: Screen = .home

    private let ceremonyTransitionDurationNanoseconds: UInt64 = 1_000_000_000
    private let entryVideoStartWaitTimeoutNanoseconds: UInt64 = 4_000_000_000
    private let entryVideoStartRevealDelayNanoseconds: UInt64 = 100_000_000
    private let transitionAudioFadeDuration: TimeInterval = 1.0
    private let homeBGMFadeInDuration: TimeInterval = 5.0
    private let homeBGMTransitionVolume: Float = 0.18

    var body: some View {
        ZStack {
            switch screen {
            case .home:
                HomeView(
                    onStart: startCeremony,
                    onShowZenPhraseLibrary: showZenPhraseLibraryFromHome,
                    onShowAboutApp: showAboutApp,
                    onHomeVideoStarted: handleHomeVideoStarted,
                    homeVideoRestartToken: homeVideoRestartToken,
                    shouldAutoplayHomeVideo: shouldAutoplayHomeVideo
                )
            case .aboutApp:
                AboutAppView(
                    onBack: returnToHomeFromAboutApp,
                    onShowZenPhraseLibrary: showZenPhraseLibraryFromAboutApp
                )
            case .ceremony:
                CeremonyFlowView(
                    session: session,
                    onFinish: finishCeremony,
                    onEntryVideoStarted: handleCeremonyEntryVideoStarted
                )
            case .zenPhraseLibrary:
                ZenPhraseLibraryView(onBack: returnFromZenPhraseLibrary)
            }

            if isLaunchIntroPresented {
                LaunchIntroExperienceView(
                    onDoorOpeningStarted: restartHomeVideoFromBeginning,
                    onFinished: dismissLaunchIntro
                )
            }

            Color.black
                .opacity(transitionOverlayOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(isCeremonyTransitionRunning || transitionOverlayOpacity > 0.01)
        }
        .onAppear {
            bootstrapAudioIfNeeded()
        }
        .onChange(of: screen) { newScreen in
            handleAudioForScreenChange(newScreen)
        }
    }

    private func startCeremony(mode: CeremonyMode) {
        guard !isCeremonyTransitionRunning else { return }
        prepareAudioForTransition(from: screen, to: .ceremony)
        session.configure(mode: mode)

        ceremonyTransitionTask?.cancel()
        ceremonyTransitionTask = Task { @MainActor in
            isCeremonyTransitionRunning = true

            withAnimation(.easeInOut(duration: 1.0)) {
                transitionOverlayOpacity = 1
            }
            try? await Task.sleep(nanoseconds: ceremonyTransitionDurationNanoseconds)
            guard !Task.isCancelled else {
                isCeremonyTransitionRunning = false
                transitionOverlayOpacity = 0
                ceremonyTransitionTask = nil
                return
            }

            hasCeremonyEntryVideoStarted = false
            screen = .ceremony

            var waitedNanoseconds: UInt64 = 0
            let pollIntervalNanoseconds: UInt64 = 50_000_000
            while !hasCeremonyEntryVideoStarted && waitedNanoseconds < entryVideoStartWaitTimeoutNanoseconds {
                try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                waitedNanoseconds += pollIntervalNanoseconds

                if Task.isCancelled {
                    isCeremonyTransitionRunning = false
                    transitionOverlayOpacity = 0
                    ceremonyTransitionTask = nil
                    return
                }
            }

            if hasCeremonyEntryVideoStarted {
                try? await Task.sleep(nanoseconds: entryVideoStartRevealDelayNanoseconds)
                if Task.isCancelled {
                    isCeremonyTransitionRunning = false
                    transitionOverlayOpacity = 0
                    ceremonyTransitionTask = nil
                    return
                }
            }

            withAnimation(.easeInOut(duration: 1.0)) {
                transitionOverlayOpacity = 0
            }
            try? await Task.sleep(nanoseconds: ceremonyTransitionDurationNanoseconds)
            guard !Task.isCancelled else {
                isCeremonyTransitionRunning = false
                transitionOverlayOpacity = 0
                ceremonyTransitionTask = nil
                return
            }

            isCeremonyTransitionRunning = false
            ceremonyTransitionTask = nil
        }
    }

    private func finishCeremony() {
        guard !isCeremonyTransitionRunning else { return }
        audioManager.fadeCurrentBGMVolume(to: 0, duration: transitionAudioFadeDuration)

        ceremonyTransitionTask?.cancel()
        ceremonyTransitionTask = Task { @MainActor in
            isCeremonyTransitionRunning = true

            withAnimation(.easeInOut(duration: 1.0)) {
                transitionOverlayOpacity = 1
            }
            try? await Task.sleep(nanoseconds: ceremonyTransitionDurationNanoseconds)
            guard !Task.isCancelled else {
                isCeremonyTransitionRunning = false
                transitionOverlayOpacity = 0
                ceremonyTransitionTask = nil
                return
            }

            hasCeremonyEntryVideoStarted = false
            session.reset()
            hasStartedHomeBGM = true
            audioManager.playBGM(.home, restartIfSameTrack: true, fadeInDuration: homeBGMFadeInDuration)
            screen = .home

            withAnimation(.easeInOut(duration: 1.0)) {
                transitionOverlayOpacity = 0
            }
            try? await Task.sleep(nanoseconds: ceremonyTransitionDurationNanoseconds)
            guard !Task.isCancelled else {
                isCeremonyTransitionRunning = false
                transitionOverlayOpacity = 0
                ceremonyTransitionTask = nil
                return
            }

            isCeremonyTransitionRunning = false
            ceremonyTransitionTask = nil
        }
    }

    private func handleCeremonyEntryVideoStarted() {
        hasCeremonyEntryVideoStarted = true
        audioManager.playBGM(.session, restartIfSameTrack: true)
    }

    private func showAboutApp() {
        transitionBetweenInformationalScreens(to: .aboutApp)
    }

    private func showZenPhraseLibraryFromHome() {
        zenPhraseLibraryBackDestination = .home
        transitionBetweenInformationalScreens(to: .zenPhraseLibrary)
    }

    private func returnToHomeFromAboutApp() {
        transitionBetweenInformationalScreens(to: .home)
    }

    private func showZenPhraseLibraryFromAboutApp() {
        zenPhraseLibraryBackDestination = .aboutApp
        transitionBetweenInformationalScreens(to: .zenPhraseLibrary)
    }

    private func returnFromZenPhraseLibrary() {
        transitionBetweenInformationalScreens(to: zenPhraseLibraryBackDestination)
    }

    private func transitionBetweenInformationalScreens(to destination: Screen) {
        guard !isCeremonyTransitionRunning else { return }
        let sourceScreen = screen
        prepareAudioForTransition(from: sourceScreen, to: destination)

        ceremonyTransitionTask?.cancel()
        ceremonyTransitionTask = Task { @MainActor in
            isCeremonyTransitionRunning = true

            withAnimation(.easeInOut(duration: 1.0)) {
                transitionOverlayOpacity = 1
            }
            try? await Task.sleep(nanoseconds: ceremonyTransitionDurationNanoseconds)
            guard !Task.isCancelled else {
                isCeremonyTransitionRunning = false
                transitionOverlayOpacity = 0
                ceremonyTransitionTask = nil
                return
            }

            screen = destination
            restoreAudioAfterTransition(from: sourceScreen, to: destination)

            withAnimation(.easeInOut(duration: 1.0)) {
                transitionOverlayOpacity = 0
            }
            try? await Task.sleep(nanoseconds: ceremonyTransitionDurationNanoseconds)
            guard !Task.isCancelled else {
                isCeremonyTransitionRunning = false
                transitionOverlayOpacity = 0
                ceremonyTransitionTask = nil
                return
            }

            isCeremonyTransitionRunning = false
            ceremonyTransitionTask = nil
        }
    }

    private func dismissLaunchIntro() {
        isLaunchIntroPresented = false
    }

    private func restartHomeVideoFromBeginning() {
        shouldAutoplayHomeVideo = true
        homeVideoRestartToken = UUID()
    }

    private func bootstrapAudioIfNeeded() {
        guard !hasBootstrappedAudio else { return }
        hasBootstrappedAudio = true
        audioManager.bootstrapIfNeeded()
    }

    private func handleHomeVideoStarted() {
        guard !hasStartedHomeBGM else { return }
        hasStartedHomeBGM = true
        audioManager.playBGM(.home, restartIfSameTrack: true, fadeInDuration: homeBGMFadeInDuration)
    }

    private func handleAudioForScreenChange(_ newScreen: Screen) {
        switch newScreen {
        case .ceremony:
            audioManager.pauseBGM()
        case .home, .aboutApp, .zenPhraseLibrary:
            guard hasStartedHomeBGM else { return }
            audioManager.resumeBGM()
        }
    }

    private func prepareAudioForTransition(from source: Screen, to destination: Screen) {
        guard hasStartedHomeBGM else { return }
        guard source == .home, destination != .home else { return }
        audioManager.fadeCurrentBGMVolume(
            to: homeBGMTransitionVolume,
            duration: transitionAudioFadeDuration
        )
    }

    private func restoreAudioAfterTransition(from source: Screen, to destination: Screen) {
        guard hasStartedHomeBGM else { return }

        let shouldRestore =
            (source == .home && (destination == .aboutApp || destination == .zenPhraseLibrary))

        guard shouldRestore else { return }
        audioManager.restoreBGMVolume(duration: transitionAudioFadeDuration)
    }
}
