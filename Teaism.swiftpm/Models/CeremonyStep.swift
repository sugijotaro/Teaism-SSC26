import Foundation

enum CeremonyStep: Hashable {
    case opening
    case guestQuestion
    case keywordSelection
    case zenScroll
    case zenPhraseMeaning
    case hostServe
    case guestReceive
    case sharedSip
    case closing
    case soloBowlGesture
    case soloJournal

    enum FocusSide {
        case leftHost
        case rightGuest
        case both
    }

    static func sequence(for mode: CeremonyMode) -> [CeremonyStep] {
        switch mode {
        case .solo:
            return [
                .opening,
                .keywordSelection,
                .zenScroll,
                .zenPhraseMeaning,
                .soloBowlGesture,
                .sharedSip,
                .soloJournal
            ]
        case .pair:
            return [
                .opening,
                .guestQuestion,
                .keywordSelection,
                .zenScroll,
                .zenPhraseMeaning,
                .hostServe,
                .guestReceive,
                .sharedSip,
                .closing
            ]
        }
    }
}

struct CeremonyStepContent {
    let roleLabel: String
    let title: String
    let instruction: String
    let commentary: String?
    let actionTitle: String
    let actionSubtitle: String?
    let focusSide: CeremonyStep.FocusSide

    init(
        roleLabel: String,
        title: String,
        instruction: String,
        commentary: String? = nil,
        actionTitle: String,
        actionSubtitle: String? = "Tap to continue",
        focusSide: CeremonyStep.FocusSide
    ) {
        self.roleLabel = roleLabel
        self.title = title
        self.instruction = instruction
        self.commentary = commentary
        self.actionTitle = actionTitle
        self.actionSubtitle = actionSubtitle
        self.focusSide = focusSide
    }
}
