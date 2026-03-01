import Foundation

enum CeremonyCategory: String, CaseIterable, Hashable {
    case hospitality
    case selfCultivation
    case tranquility
    case celebration
    case resilience

    var label: String {
        switch self {
        case .hospitality:
            return "Hospitality and Devotion"
        case .selfCultivation:
            return "Self-Cultivation and Reflection"
        case .tranquility:
            return "Calm and Peace"
        case .celebration:
            return "Blessing and Celebration"
        case .resilience:
            return "Adversity and Turning Points"
        }
    }

    var hostIntention: String {
        switch self {
        case .hospitality:
            return "Create a host-guest unity space and welcome the guest sincerely."
        case .selfCultivation:
            return "Let go of ego and keep refining both movement and mind."
        case .tranquility:
            return "Settle distractions and open calm in the present moment."
        case .celebration:
            return "Share joy for longevity, prosperity, and meaningful milestones."
        case .resilience:
            return "Draw out courage to face adversity and turning points."
        }
    }
}
