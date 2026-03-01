import Foundation

struct ZenPhrase: Identifiable, Hashable {
    let id: String
    let phrase: String
    let reading: String
    let translation: String
    let meaning: String
    let categories: Set<CeremonyCategory>

    var scrollImageAssetName: String {
        "zen_scroll_\(id)"
    }
}
