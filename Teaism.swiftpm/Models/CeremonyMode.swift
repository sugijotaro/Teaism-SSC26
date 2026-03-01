import Foundation

enum CeremonyMode: String, Hashable {
    case solo
    case pair

    var title: String {
        switch self {
        case .solo:
            return "Solo"
        case .pair:
            return "Pair"
        }
    }

    var subtitle: String {
        switch self {
        case .solo:
            return "A quiet flow for inner balance"
        case .pair:
            return "A shared flow for building one gathering"
        }
    }
}
