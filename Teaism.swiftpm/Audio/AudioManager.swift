import AVFoundation
import Foundation

final class AudioManager: NSObject {
    struct AudioClip: Hashable {
        let name: String
        let fileExtensions: [String]

        init(name: String, fileExtension: String) {
            self.name = name
            self.fileExtensions = [fileExtension]
        }

        init(name: String, fileExtensions: [String]) {
            self.name = name
            self.fileExtensions = fileExtensions
        }
    }

    enum BGMTrack {
        case home
        case session

        fileprivate var clip: AudioClip {
            switch self {
            case .home:
                return AudioClip(name: "home", fileExtension: "wav")
            case .session:
                return AudioClip(name: "session", fileExtension: "mp3")
            }
        }
    }

    private struct VoiceSegment {
        let start: TimeInterval
        let end: TimeInterval
    }

    static let shared = AudioManager()

    private let session = AVAudioSession.sharedInstance()
    private var hasConfiguredSession = false
    private var bgmPlayer: AVAudioPlayer?
    private var bgmVolumeTask: Task<Void, Never>?
    private var currentBGMClip: AudioClip?
    private var voicePlayer: AVAudioPlayer?
    private var voiceStopTask: Task<Void, Never>?
    private var bgmVolumeBeforeVoicePlayback: Float?
    private var shouldResumeBGMAfterInterruption = false
    private var missingResourceKeys: Set<String> = []

    private(set) var isBGMEnabled = true

    var bgmVolume: Float = 0.5 {
        didSet {
            bgmPlayer?.volume = clampedVolume(bgmVolume)
        }
    }

    private let voiceBGMDuckRatio: Float = 0.35
    private let voiceBGMDuckFadeDuration: TimeInterval = 0.2
    private let voiceBGMRestoreFadeDuration: TimeInterval = 0.35

    private override init() {
        super.init()
        registerForAudioSessionNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func bootstrapIfNeeded(defaultBGM: BGMTrack? = nil) {
        configureSessionIfNeeded()
        if let defaultBGM {
            playBGM(defaultBGM)
        }
    }

    func configureSessionIfNeeded() {
        guard !hasConfiguredSession else { return }

        do {
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            hasConfiguredSession = true
        } catch {
            debugLog("Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
    }

    func setBGMEnabled(_ enabled: Bool) {
        isBGMEnabled = enabled
        if enabled {
            resumeBGM()
        } else {
            pauseBGM()
        }
    }

    func playBGM(_ track: BGMTrack, restartIfSameTrack: Bool = false) {
        playBGM(track.clip, restartIfSameTrack: restartIfSameTrack)
    }

    func playBGM(
        _ track: BGMTrack,
        restartIfSameTrack: Bool = false,
        fadeInDuration: TimeInterval
    ) {
        playBGM(track.clip, restartIfSameTrack: restartIfSameTrack, fadeInDuration: fadeInDuration)
    }

    func playBGM(
        _ clip: AudioClip,
        restartIfSameTrack: Bool = false,
        loop: Bool = true,
        volume: Float? = nil,
        fadeInDuration: TimeInterval = 0
    ) {
        guard isBGMEnabled else { return }
        configureSessionIfNeeded()

        if !restartIfSameTrack, currentBGMClip == clip, let bgmPlayer, bgmPlayer.isPlaying {
            return
        }

        guard let url = resolvedURL(for: clip) else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = loop ? -1 : 0
            let targetVolume = clampedVolume(volume ?? bgmVolume)
            player.volume = fadeInDuration > 0 ? 0 : targetVolume
            player.prepareToPlay()
            player.play()

            cancelBGMVolumeTask()
            bgmPlayer?.stop()
            bgmPlayer = player
            currentBGMClip = clip

            if fadeInDuration > 0 {
                startBGMVolumeFade(for: player, from: 0, to: targetVolume, duration: fadeInDuration)
            }
        } catch {
            debugLog("Failed to start BGM \(clip.name): \(error.localizedDescription)")
        }
    }

    func pauseBGM() {
        cancelBGMVolumeTask()
        bgmPlayer?.pause()
    }

    func resumeBGM() {
        guard isBGMEnabled else { return }
        configureSessionIfNeeded()
        bgmPlayer?.play()
    }

    func stopBGM() {
        cancelBGMVolumeTask()
        bgmPlayer?.stop()
        bgmPlayer = nil
        currentBGMClip = nil
        bgmVolumeBeforeVoicePlayback = nil
    }

    func fadeCurrentBGMVolume(to volume: Float, duration: TimeInterval) {
        guard let bgmPlayer else { return }
        let target = clampedVolume(volume)
        if duration <= 0 {
            cancelBGMVolumeTask()
            bgmPlayer.volume = target
            return
        }

        startBGMVolumeFade(for: bgmPlayer, from: bgmPlayer.volume, to: target, duration: duration)
    }

    func restoreBGMVolume(duration: TimeInterval = 0) {
        fadeCurrentBGMVolume(to: bgmVolume, duration: duration)
    }

    func playCeremonyStepVoice(step: CeremonyStep, mode: CeremonyMode) {
        guard let segment = voiceSegment(for: step, mode: mode) else { return }
        playVoiceSegment(start: segment.start, end: segment.end)
    }

    func stopCeremonyStepVoice() {
        restoreBGMVolumeAfterVoiceIfNeeded()
        stopCeremonyStepVoiceWithoutMixRestore()
    }

    private func stopCeremonyStepVoiceWithoutMixRestore() {
        cancelVoiceStopTask()
        voicePlayer?.stop()
        voicePlayer = nil
    }

    private func playVoiceSegment(start: TimeInterval, end: TimeInterval) {
        guard end > start else { return }
        configureSessionIfNeeded()
        guard let url = resolvedURL(for: AudioClip(name: "voice", fileExtension: "mp3")) else { return }

        stopCeremonyStepVoiceWithoutMixRestore()

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.prepareToPlay()

            let clampedStart = min(max(start, 0), player.duration)
            let playableDuration = max(player.duration - clampedStart, 0)
            let duration = min(end - start, playableDuration)
            guard duration > 0 else {
                restoreBGMVolumeAfterVoiceIfNeeded()
                return
            }

            player.currentTime = clampedStart
            guard player.play() else {
                restoreBGMVolumeAfterVoiceIfNeeded()
                return
            }

            voicePlayer = player
            duckBGMForVoicePlayback()
            scheduleVoiceStop(for: player, after: duration)
        } catch {
            debugLog("Failed to start voice.mp3 playback: \(error.localizedDescription)")
            restoreBGMVolumeAfterVoiceIfNeeded()
        }
    }

    private func scheduleVoiceStop(for player: AVAudioPlayer, after duration: TimeInterval) {
        cancelVoiceStopTask()
        voiceStopTask = Task { [weak self, weak player] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled, let self, let player else { return }
            await self.stopVoiceIfCurrent(player)
        }
    }

    private func cancelVoiceStopTask() {
        voiceStopTask?.cancel()
        voiceStopTask = nil
    }

    private func duckBGMForVoicePlayback() {
        guard let bgmPlayer, bgmPlayer.isPlaying else { return }
        if bgmVolumeBeforeVoicePlayback == nil {
            bgmVolumeBeforeVoicePlayback = clampedVolume(bgmPlayer.volume)
        }

        let sourceVolume = bgmVolumeBeforeVoicePlayback ?? bgmPlayer.volume
        let targetVolume = clampedVolume(sourceVolume * voiceBGMDuckRatio)
        fadeCurrentBGMVolume(to: targetVolume, duration: voiceBGMDuckFadeDuration)
    }

    private func restoreBGMVolumeAfterVoiceIfNeeded() {
        guard let restoreVolume = bgmVolumeBeforeVoicePlayback else { return }
        bgmVolumeBeforeVoicePlayback = nil
        fadeCurrentBGMVolume(to: restoreVolume, duration: voiceBGMRestoreFadeDuration)
    }

    private func voiceSegment(for step: CeremonyStep, mode: CeremonyMode) -> VoiceSegment? {
        switch mode {
        case .solo:
            switch step {
            case .opening:
                return VoiceSegment(start: 0, end: 4)
            case .keywordSelection:
                return VoiceSegment(start: 4, end: 8)
            case .zenScroll:
                return VoiceSegment(start: 8, end: 12)
            case .zenPhraseMeaning:
                return VoiceSegment(start: 12, end: 15)
            case .soloBowlGesture:
                return VoiceSegment(start: 15, end: 21)
            case .sharedSip:
                return VoiceSegment(start: 21, end: 25)
            case .soloJournal:
                return VoiceSegment(start: 25, end: 29)
            case .guestQuestion, .hostServe, .guestReceive, .closing:
                return nil
            }

        case .pair:
            switch step {
            case .opening:
                return VoiceSegment(start: 29, end: 32)
            case .guestQuestion:
                return VoiceSegment(start: 32, end: 36)
            case .keywordSelection:
                return VoiceSegment(start: 36, end: 40)
            case .zenScroll:
                return VoiceSegment(start: 40, end: 43)
            case .zenPhraseMeaning:
                return VoiceSegment(start: 43, end: 46)
            case .hostServe:
                return VoiceSegment(start: 46, end: 50)
            case .guestReceive:
                return VoiceSegment(start: 50, end: 59)
            case .sharedSip:
                return VoiceSegment(start: 59, end: 63)
            case .closing:
                return VoiceSegment(start: 63, end: 68)
            case .soloBowlGesture, .soloJournal:
                return nil
            }
        }
    }

    private func registerForAudioSessionNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
    }

    private func startBGMVolumeFade(
        for player: AVAudioPlayer,
        from startVolume: Float,
        to targetVolume: Float,
        duration: TimeInterval
    ) {
        guard duration > 0 else {
            player.volume = targetVolume
            return
        }

        cancelBGMVolumeTask()
        let steps = max(Int(duration / 0.05), 1)
        let stepDuration = duration / Double(steps)

        bgmVolumeTask = Task { [weak self, weak player] in
            for step in 1 ... steps {
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                if Task.isCancelled { return }
                guard let self, let player else { return }
                let progress = Float(step) / Float(steps)
                let nextVolume = startVolume + ((targetVolume - startVolume) * progress)
                await self.applyBGMVolumeStepIfCurrent(player, nextVolume: nextVolume)
            }
        }
    }

    private func cancelBGMVolumeTask() {
        bgmVolumeTask?.cancel()
        bgmVolumeTask = nil
    }

    @MainActor
    private func stopVoiceIfCurrent(_ player: AVAudioPlayer) {
        guard voicePlayer === player else { return }
        player.stop()
        voicePlayer = nil
        voiceStopTask = nil
        restoreBGMVolumeAfterVoiceIfNeeded()
    }

    @MainActor
    private func applyBGMVolumeStepIfCurrent(_ player: AVAudioPlayer, nextVolume: Float) {
        guard bgmPlayer === player else { return }
        player.volume = clampedVolume(nextVolume)
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            shouldResumeBGMAfterInterruption = bgmPlayer?.isPlaying == true
            pauseBGM()
            stopCeremonyStepVoice()

        case .ended:
            do {
                try session.setActive(true)
            } catch {
                debugLog("Failed to reactivate AVAudioSession after interruption: \(error.localizedDescription)")
            }

            guard shouldResumeBGMAfterInterruption else { return }
            let rawOptions = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if options.contains(.shouldResume) {
                resumeBGM()
            }
            shouldResumeBGMAfterInterruption = false

        @unknown default:
            break
        }
    }

    private func resolvedURL(for clip: AudioClip) -> URL? {
        for fileExtension in clip.fileExtensions {
            if let url = Bundle.main.url(forResource: clip.name, withExtension: fileExtension) {
                return url
            }
        }

        let missingKey = "\(clip.name)|\(clip.fileExtensions.joined(separator: ","))"
        if missingResourceKeys.insert(missingKey).inserted {
            debugLog("Missing audio resource: \(clip.name).{\(clip.fileExtensions.joined(separator: ","))}")
        }
        return nil
    }

    private func clampedVolume(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("[AudioManager] \(message)")
#endif
    }
}
