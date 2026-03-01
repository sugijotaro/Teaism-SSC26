import Foundation

struct CeremonyKeyword: Identifiable, Hashable {
    let id: String
    let title: String
    let category: CeremonyCategory
}
