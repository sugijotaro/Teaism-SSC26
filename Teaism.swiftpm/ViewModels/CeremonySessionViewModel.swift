import Foundation

@MainActor
final class CeremonySessionViewModel: ObservableObject {
    @Published private(set) var mode: CeremonyMode = .pair
    @Published private(set) var steps: [CeremonyStep] = CeremonyStep.sequence(for: .pair)
    @Published private(set) var step: CeremonyStep = .opening
    @Published private(set) var selectedKeywords: Set<CeremonyKeyword> = []
    @Published private(set) var selectedZenPhrase: ZenPhrase = CeremonyCatalog.defaultPhrase(for: .pair)
    @Published var isAutoVoiceModeEnabled = false {
        didSet {
            if isAutoVoiceModeEnabled {
                playCurrentStepVoiceIfNeeded()
            } else {
                stopCurrentStepVoicePlayback()
            }
        }
    }

    private let audioManager = AudioManager.shared

    var zenPhrase: ZenPhrase {
        selectedZenPhrase
    }

    var selectedKeywordTitles: [String] {
        selectedKeywords.map(\.title).sorted()
    }

    var availableKeywords: [CeremonyKeyword] {
        CeremonyCatalog.keywords(for: mode)
    }

    var isSoloMode: Bool {
        mode == .solo
    }

    var currentStepIndex: Int {
        steps.firstIndex(of: step) ?? 0
    }

    var currentStepContent: CeremonyStepContent {
        content(for: step)
    }

    var keywordPromptTitle: String {
        switch mode {
        case .solo:
            return "Your current state (select multiple)"
        case .pair:
            return "Your intention for this session (select multiple)"
        }
    }

    var showsPersistentZenScroll: Bool {
        switch step {
        case .zenPhraseMeaning, .hostServe, .guestReceive, .sharedSip, .closing, .soloBowlGesture, .soloJournal:
            return true
        default:
            return false
        }
    }

    var canAdvanceBySessionState: Bool {
        switch step {
        case .keywordSelection:
            return !selectedKeywords.isEmpty
        default:
            return true
        }
    }

    func configure(mode: CeremonyMode) {
        self.mode = mode
        steps = CeremonyStep.sequence(for: mode)
        reset()
    }

    func toggleKeyword(_ keyword: CeremonyKeyword) {
        if selectedKeywords.contains(keyword) {
            selectedKeywords.remove(keyword)
        } else {
            selectedKeywords.insert(keyword)
        }
    }

    func nextStep() {
        guard currentStepIndex + 1 < steps.count else { return }
        let nextStep = steps[currentStepIndex + 1]
        if nextStep == .zenScroll {
            selectedZenPhrase = CeremonyCatalog.zenPhraseAvoidingImmediateRepeat(
                for: selectedKeywords,
                mode: mode
            )
        }
        step = nextStep
    }

    func previousStep() {
        guard currentStepIndex > 0 else { return }
        step = steps[currentStepIndex - 1]
    }

    func reset() {
        isAutoVoiceModeEnabled = false
        step = steps.first ?? .opening
        selectedKeywords.removeAll()
        selectedZenPhrase = CeremonyCatalog.defaultPhrase(for: mode)
        stopCurrentStepVoicePlayback()
    }

    private func content(for step: CeremonyStep) -> CeremonyStepContent {
        switch step {
        case .opening:
            switch mode {
            case .solo:
                return CeremonyStepContent(
                    roleLabel: "To Yourself",
                    title: "Align your posture and bow quietly",
                    instruction: "Slow your breathing and take a gentle bow.",
                    commentary: "In a formal tea ceremony, the host and guest cooperate as equals to create a shared space. In solo mode, you begin as both host and guest. Chazen ichimi (茶禅一味) teaches that tea and Zen are one in essence. Preparing tea itself can be a path of practice that turns your attention inward.",
                    actionTitle: "Next",
                    focusSide: .both
                )
            case .pair:
                return CeremonyStepContent(
                    roleLabel: "To Both of You",
                    title: "Face each other and bow",
                    instruction: "Take a breath together and bow gently.",
                    commentary: "Shukyaku Ittai (主客一体) describes host and guest creating a gathering together as equals. Begin this session with a bow so mutual respect sets the tone.",
                    actionTitle: "Next",
                    focusSide: .both
                )
            }
        case .guestQuestion:
            return CeremonyStepContent(
                roleLabel: "To the Right Side (Guest)",
                title: "Ask, \"What inspired you to host our tea today?\"",
                instruction: "Ask the host and draw out the intention behind this session.",
                commentary: "In tea culture, the reason for holding a gathering is called shuko (趣向), the guiding theme. By asking and listening, a warm exchange begins between two people.",
                actionTitle: "Next",
                actionSubtitle: "Tap after asking",
                focusSide: .rightGuest
            )
        case .keywordSelection:
            switch mode {
            case .solo:
                return CeremonyStepContent(
                    roleLabel: "To Yourself",
                    title: "Check in with yourself and choose your words",
                    instruction: "Select multiple keywords close to how you feel and quietly observe your inner state.",
                    commentary: "To settle the mind away from daily noise, begin by observing your inner state mindfully. Zen teaches shikantaza (只管打坐), just sitting without extra thought. Here, put your present feeling into words as you prepare to receive this bowl of tea. That becomes your theme for this moment.",
                    actionTitle: "Next",
                    actionSubtitle: "Tap after selecting keywords",
                    focusSide: .both
                )
            case .pair:
                return CeremonyStepContent(
                    roleLabel: "To the Left Side (Host)",
                    title: "Speak your reason for hosting out loud",
                    instruction: "Share why you held this gathering, then choose multiple keywords that match your feeling.",
                    commentary: "Traditionally, a host spends far more time preparing than the gathering itself: refining the theme, selecting tea wares, and arranging the setting. This app simplifies that process, but through this session the host can still clarify and express their intention.",
                    actionTitle: "Next",
                    actionSubtitle: "Tap after selecting keywords",
                    focusSide: .leftHost
                )
            }
        case .zenScroll:
            switch mode {
            case .solo:
                return CeremonyStepContent(
                    roleLabel: "To Yourself",
                    title: "View the hanging scroll in silence",
                    instruction: "Receive the Zen phrase chosen for you by first gazing at it.",
                    commentary: "Tea and Zen have long been connected. Monks first drank tea to stay awake, then discovered deep truth in the ordinary act of drinking. The words on this scroll can mirror your inner state. Let yourself touch the heart of Zen behind them.",
                    actionTitle: "View Meaning",
                    actionSubtitle: "Tap to read the meaning",
                    focusSide: .both
                )
            case .pair:
                return CeremonyStepContent(
                    roleLabel: "To Both of You",
                    title: "View the hanging scroll in silence",
                    instruction: "First, look together at the Zen phrase chosen for this gathering.",
                    commentary: nil,
                    actionTitle: "View Meaning",
                    actionSubtitle: "Tap to read the meaning",
                    focusSide: .both
                )
            }
        case .zenPhraseMeaning:
            switch mode {
            case .solo:
                return CeremonyStepContent(
                    roleLabel: "To Yourself",
                    title: "Savor the meaning of the phrase",
                    instruction: "Follow the reading and meaning, then notice how it resonates with you now.",
                    commentary: "Sen no Rikyu said that in the tea room, no element is more important than the hanging scroll. It expresses the theme of the gathering, and many scroll phrases are concise forms of Zen insight. Tea and Zen are deeply connected, a unity expressed in chazen ichimi (茶禅一味).",
                    actionTitle: "Next",
                    actionSubtitle: "Tap after reflecting on the meaning",
                    focusSide: .rightGuest
                )
            case .pair:
                return CeremonyStepContent(
                    roleLabel: "To Both of You",
                    title: "Savor the meaning of the phrase",
                    instruction: "Trace the meaning and feel how it resonates with both of you now.",
                    commentary: "Traditionally this is a time for mondo (問答), where the guest asks about the host's chosen phrase and intention. In this app, both host and guest read together as shared Zen reflection. This phrase is a message chosen for this exact moment.",
                    actionTitle: "Next",
                    actionSubtitle: "Tap after reflecting on the meaning",
                    focusSide: .rightGuest
                )
            }
        case .hostServe:
            return CeremonyStepContent(
                roleLabel: "To the Left Side (Host)",
                title: "Pass the drink to your partner with care",
                instruction: "Make eye contact and offer it with both hands. The gesture itself is hospitality.",
                commentary: "In full tea procedure, the host prepares tea through detailed established movements while the guest watches quietly.",
                actionTitle: "Next",
                actionSubtitle: "Tap after passing it",
                focusSide: .leftHost
            )
        case .guestReceive:
            return CeremonyStepContent(
                roleLabel: "To the Right Side (Guest)",
                title: "Express gratitude: \"Otemae chodai itashimasu\" (Thank you for the tea.)",
                instruction: "You may say \"Otemae chodai itashimasu\" or simply \"Thank you for the tea,\" then bow gently before receiving.",
                commentary: "This phrase is often rendered as \"Thank you for the tea\" or \"Thank you for preparing the tea.\" It expresses receiving the host's wholehearted care for the entire session.",
                actionTitle: "Next",
                actionSubtitle: "Tap after expressing thanks",
                focusSide: .rightGuest
            )
        case .sharedSip:
            switch mode {
            case .solo:
                return CeremonyStepContent(
                    roleLabel: "To Yourself",
                    title: "Sip slowly and mindfully",
                    instruction: "Notice aroma, temperature, and sensation as the drink passes your throat.",
                    commentary: "The final sip is called suikiri (吸い切り). Intentionally making a slurping sound on the final sip expresses gratitude for the whole bowl and marks completion. Stay with the taste that exists only in this moment and savor the last drop.",
                    actionTitle: "To Closing",
                    actionSubtitle: "Tap to move to closing",
                    focusSide: .both
                )
            case .pair:
                return CeremonyStepContent(
                    roleLabel: "To Both of You",
                    title: "Enjoy the drink together and rest in the moment",
                    instruction: "Share one quiet moment while savoring your drinks.",
                    commentary: "In a formal tea ceremony, the host usually does not drink and focuses on serving the guest. In this app, Teaism is adapted for daily life, so the goal here is to enjoy not only the tea itself but also the shared atmosphere.",
                    actionTitle: "To Closing",
                    actionSubtitle: "Tap to move to closing",
                    focusSide: .both
                )
            }
        case .closing:
            return CeremonyStepContent(
                roleLabel: "To Both of You",
                title: "Share a reflection or gratitude with each other",
                instruction: "Close by sharing one insight or one thank-you from today.",
                commentary: "This is the final moment of the session. In tea culture, after drinking, there is a moment called haiken (拝見) to appreciate the tea wares. Put your insight into words, feel the lingering afterglow, and stand up with a clear heart.",
                actionTitle: "Finish Session",
                actionSubtitle: "Tap to return home",
                focusSide: .both
            )
        case .soloBowlGesture:
            return CeremonyStepContent(
                roleLabel: "To Yourself",
                title: "Handle the vessel with care and offer one serving to yourself",
                instruction: "Feel the weight of the vessel and treat yourself with the same hospitality you would offer another.",
                commentary: "Pay attention to each movement of your fingertips and settle your mind. Gestures like turning the bowl show humility by avoiding drinking from its \"front\" (the side with the most beautiful design). That respect toward yourself naturally extends to others.",
                actionTitle: "Next",
                focusSide: .both
            )
        case .soloJournal:
            return CeremonyStepContent(
                roleLabel: "To Yourself",
                title: "Reflect on what you want to carry forward",
                instruction: "Quietly confirm in your heart what you want to cherish going forward.",
                commentary: "This is a moment of zanshin (残心), a lingering mind. Even after formal movement ends, awareness remains as if reluctant to part from someone dear. Carry the aftertaste of tea with gratitude toward people and tea wares. It echoes shikantaza in Soto Zen: sustaining stillness beyond the act itself. Bring that quiet into daily life.",
                actionTitle: "Finish Session",
                actionSubtitle: "Tap to return home",
                focusSide: .both
            )
        }
    }

    func playCurrentStepVoiceIfNeeded() {
        guard isAutoVoiceModeEnabled else {
            stopCurrentStepVoicePlayback()
            return
        }
        audioManager.playCeremonyStepVoice(step: step, mode: mode)
    }

    func stopCurrentStepVoicePlayback() {
        audioManager.stopCeremonyStepVoice()
    }
}
