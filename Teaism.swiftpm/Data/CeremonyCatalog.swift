import Foundation

enum CeremonyCatalog {
    static let pairKeywords: [CeremonyKeyword] = [
        CeremonyKeyword(id: "host-hospitality", title: "Hospitality", category: .hospitality),
        CeremonyKeyword(id: "host-tranquility", title: "Tranquility", category: .tranquility),
        CeremonyKeyword(id: "host-celebration", title: "Celebration", category: .celebration),
        CeremonyKeyword(id: "host-turning-point", title: "Turning Point", category: .resilience),
        CeremonyKeyword(id: "host-self-cultivation", title: "Self-Cultivation", category: .selfCultivation)
    ]

    static let soloKeywords: [CeremonyKeyword] = [
        CeremonyKeyword(id: "solo-tranquility", title: "Tranquility", category: .tranquility),
        CeremonyKeyword(id: "solo-turning-point", title: "Turning Point", category: .resilience),
        CeremonyKeyword(id: "solo-self-cultivation", title: "Self-Cultivation", category: .selfCultivation),
        CeremonyKeyword(id: "solo-celebration", title: "Celebration", category: .celebration)
    ]

    static var allKeywords: [CeremonyKeyword] {
        pairKeywords
    }

    static let zenPhrases: [ZenPhrase] = [
        ZenPhrase(
            id: "ichigo-ichie",
            phrase: "一期一会",
            reading: "ichigo ichie",
            translation: "One Time, One Meeting",
            meaning: "Ichigo means a lifetime. Even if the same host and guest meet again, this exact gathering will never return. The host prepares with full sincerity, and the guest lets go of distraction to devote themselves to this one bowl in the present moment.",
            categories: [.hospitality, .celebration]
        ),
        ZenPhrase(
            id: "kissako",
            phrase: "喫茶去",
            reading: "kissako",
            translation: "Come, Have Tea",
            meaning: "From a koan of Zen master Joshu, this phrase invites everyone equally to tea regardless of background or skill. It asks us to set titles and arguments aside and share one bowl in a spirit of equality and release.",
            categories: [.hospitality, .tranquility]
        ),
        ZenPhrase(
            id: "wakei-seijaku",
            phrase: "和敬清寂",
            reading: "wakei seijaku",
            translation: "Harmony, Respect, Purity, Tranquility",
            meaning: "These are the four principles of tea: harmony, respect, purity, and tranquility. Host and guest come together in harmony, honor one another, purify the place and mind, and arrive at stillness. It is a core philosophy that supports each shared gathering.",
            categories: [.hospitality, .selfCultivation]
        ),
        ZenPhrase(
            id: "byojo-shin-kore-do",
            phrase: "平常心是道",
            reading: "byojo shin kore do",
            translation: "Ordinary Mind Is the Way",
            meaning: "Rather than chasing extraordinary states, this phrase teaches that the natural mind in everyday actions is the way. Let go of display and pretense, and continue preparing tea with simple sincerity.",
            categories: [.selfCultivation, .tranquility]
        ),
        ZenPhrase(
            id: "nichinichi-kore-koujitsu",
            phrase: "日日是好日",
            reading: "nichinichi kore kojitsu",
            translation: "Every Day Is a Good Day",
            meaning: "A saying from Yunmen: not only easy days but difficult days too can be received as an unrepeatable good day. It invites us to embrace joy and hardship alike and live this one day fully.",
            categories: [.tranquility, .resilience]
        ),
        ZenPhrase(
            id: "chisoku",
            phrase: "知足",
            reading: "chisoku",
            translation: "Know Sufficiency",
            meaning: "To know sufficiency is to turn your gaze from what is missing to what is already given. It frees the mind from endless wanting and nurtures gratitude, calm, and careful presence in the here and now.",
            categories: [.tranquility, .selfCultivation]
        ),
        ZenPhrase(
            id: "koun-ryusui",
            phrase: "行雲流水",
            reading: "koun ryusui",
            translation: "Clouds Drift, Water Flows",
            meaning: "Like drifting clouds and flowing water, this phrase points to moving with natural change without clinging. Even difficult phases are part of the flow, and we are invited to soften and adapt with flexibility.",
            categories: [.tranquility, .resilience]
        ),
        ZenPhrase(
            id: "shoju-sennen-no-midori",
            phrase: "松樹千年翠",
            reading: "shoju sennen no midori",
            translation: "Pine Remains Green for a Thousand Years",
            meaning: "The evergreen pine that stays green through winter symbolizes enduring sincerity, longevity, and the value of steady accumulation. It honors what remains essential through changing times and offers a blessing for lasting bonds.",
            categories: [.celebration, .hospitality]
        )
    ]

    static func keywords(for mode: CeremonyMode) -> [CeremonyKeyword] {
        switch mode {
        case .solo:
            return soloKeywords
        case .pair:
            return pairKeywords
        }
    }

    static func zenPhrase(for selectedKeywords: Set<CeremonyKeyword>, mode: CeremonyMode) -> ZenPhrase {
        let selectedCategories = Set(selectedKeywords.map(\.category))
        return zenPhrase(for: selectedCategories, mode: mode)
    }

    static func zenPhraseAvoidingImmediateRepeat(
        for selectedKeywords: Set<CeremonyKeyword>,
        mode: CeremonyMode,
        userDefaults: UserDefaults = .standard
    ) -> ZenPhrase {
        let selectedCategories = Set(selectedKeywords.map(\.category))
        let candidates = prioritizedPhrases(for: selectedCategories, mode: mode)
        let lastPhraseID = userDefaults.string(forKey: lastSelectedPhraseIDKey(for: mode))
        let selectedPhrase = candidates.first { $0.id != lastPhraseID } ?? candidates.first ?? defaultPhrase(for: mode)

        userDefaults.set(selectedPhrase.id, forKey: lastSelectedPhraseIDKey(for: mode))
        return selectedPhrase
    }

    private static func zenPhrase(for selectedCategories: Set<CeremonyCategory>, mode: CeremonyMode) -> ZenPhrase {
        guard !selectedCategories.isEmpty else { return defaultPhrase(for: mode) }

        if let mappedPhrase = mappedPhrase(for: selectedCategories, mode: mode) {
            return mappedPhrase
        }

        var bestPhrase = defaultPhrase(for: mode)
        var bestScore = Int.min
        for phrase in zenPhrases {
            let score = phrase.categories.intersection(selectedCategories).count
            if score > bestScore {
                bestScore = score
                bestPhrase = phrase
            }
        }
        return bestPhrase
    }

    private static func prioritizedPhrases(
        for selectedCategories: Set<CeremonyCategory>,
        mode: CeremonyMode
    ) -> [ZenPhrase] {
        let primaryPhrase = zenPhrase(for: selectedCategories, mode: mode)
        let scoredPhrases = zenPhrases
            .enumerated()
            .map { (index, phrase) in
                (
                    index: index,
                    phrase: phrase,
                    score: phrase.categories.intersection(selectedCategories).count
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.index < rhs.index
            }
            .map(\.phrase)

        var orderedPhrases = [primaryPhrase]
        for phrase in scoredPhrases where !orderedPhrases.contains(where: { $0.id == phrase.id }) {
            orderedPhrases.append(phrase)
        }
        return orderedPhrases
    }

    static func zenPhrase(for selectedKeywords: Set<CeremonyKeyword>) -> ZenPhrase {
        zenPhrase(for: selectedKeywords, mode: .pair)
    }

    static func defaultPhrase(for mode: CeremonyMode) -> ZenPhrase {
        switch mode {
        case .solo:
            return zenPhrases.first { $0.id == "nichinichi-kore-koujitsu" } ?? zenPhrases[0]
        case .pair:
            return zenPhrases.first { $0.id == "ichigo-ichie" } ?? zenPhrases[0]
        }
    }

    static var defaultPhrase: ZenPhrase {
        defaultPhrase(for: .pair)
    }

    private static func mappedPhrase(for selected: Set<CeremonyCategory>, mode: CeremonyMode) -> ZenPhrase? {
        let modeRules = phraseRules.filter { $0.mode == mode }
        let commonRules = phraseRules.filter { $0.mode == nil }

        if let exactModeRule = exactRule(in: modeRules, for: selected),
           let phrase = phrase(withID: exactModeRule.phraseID) {
            return phrase
        }

        if let exactCommonRule = exactRule(in: commonRules, for: selected),
           let phrase = phrase(withID: exactCommonRule.phraseID) {
            return phrase
        }

        if let subsetModeRule = bestSubsetRule(in: modeRules, for: selected),
           let phrase = phrase(withID: subsetModeRule.phraseID) {
            return phrase
        }

        if let subsetCommonRule = bestSubsetRule(in: commonRules, for: selected),
           let phrase = phrase(withID: subsetCommonRule.phraseID) {
            return phrase
        }

        return nil
    }

    private static func exactRule(in rules: [PhraseRule], for selected: Set<CeremonyCategory>) -> PhraseRule? {
        rules.first { $0.requiredCategories == selected }
    }

    private static func bestSubsetRule(in rules: [PhraseRule], for selected: Set<CeremonyCategory>) -> PhraseRule? {
        var bestRule: PhraseRule?
        var bestSpecificity = -1

        for rule in rules where rule.requiredCategories.isSubset(of: selected) {
            let specificity = rule.requiredCategories.count
            if specificity > bestSpecificity {
                bestSpecificity = specificity
                bestRule = rule
            }
        }

        return bestRule
    }

    private static func phrase(withID id: String) -> ZenPhrase? {
        zenPhrases.first { $0.id == id }
    }

    private static func lastSelectedPhraseIDKey(for mode: CeremonyMode) -> String {
        "ceremony.lastZenPhraseID.\(mode.rawValue)"
    }

    private static let phraseRules: [PhraseRule] = [
        PhraseRule(mode: .pair, requiredCategories: [.hospitality, .tranquility, .selfCultivation], phraseID: "wakei-seijaku"),
        PhraseRule(mode: .pair, requiredCategories: [.hospitality, .tranquility, .celebration], phraseID: "ichigo-ichie"),
        PhraseRule(mode: .pair, requiredCategories: [.tranquility, .selfCultivation, .resilience], phraseID: "byojo-shin-kore-do"),
        PhraseRule(mode: .pair, requiredCategories: [.hospitality, .tranquility], phraseID: "kissako"),
        PhraseRule(mode: .pair, requiredCategories: [.hospitality, .celebration], phraseID: "ichigo-ichie"),
        PhraseRule(mode: .pair, requiredCategories: [.hospitality, .selfCultivation], phraseID: "wakei-seijaku"),
        PhraseRule(mode: .pair, requiredCategories: [.tranquility, .selfCultivation], phraseID: "byojo-shin-kore-do"),
        PhraseRule(mode: .pair, requiredCategories: [.tranquility, .resilience], phraseID: "nichinichi-kore-koujitsu"),
        PhraseRule(mode: .pair, requiredCategories: [.selfCultivation, .resilience], phraseID: "koun-ryusui"),
        PhraseRule(mode: .pair, requiredCategories: [.celebration, .resilience], phraseID: "shoju-sennen-no-midori"),
        PhraseRule(mode: .pair, requiredCategories: [.hospitality], phraseID: "ichigo-ichie"),
        PhraseRule(mode: .pair, requiredCategories: [.tranquility], phraseID: "chisoku"),
        PhraseRule(mode: .pair, requiredCategories: [.celebration], phraseID: "shoju-sennen-no-midori"),
        PhraseRule(mode: .pair, requiredCategories: [.resilience], phraseID: "koun-ryusui"),
        PhraseRule(mode: .pair, requiredCategories: [.selfCultivation], phraseID: "byojo-shin-kore-do"),

        PhraseRule(mode: .solo, requiredCategories: [.tranquility, .selfCultivation, .resilience], phraseID: "byojo-shin-kore-do"),
        PhraseRule(mode: .solo, requiredCategories: [.tranquility, .resilience], phraseID: "koun-ryusui"),
        PhraseRule(mode: .solo, requiredCategories: [.tranquility, .selfCultivation], phraseID: "byojo-shin-kore-do"),
        PhraseRule(mode: .solo, requiredCategories: [.selfCultivation, .resilience], phraseID: "byojo-shin-kore-do"),
        PhraseRule(mode: .solo, requiredCategories: [.celebration, .resilience], phraseID: "shoju-sennen-no-midori"),
        PhraseRule(mode: .solo, requiredCategories: [.tranquility], phraseID: "nichinichi-kore-koujitsu"),
        PhraseRule(mode: .solo, requiredCategories: [.resilience], phraseID: "koun-ryusui"),
        PhraseRule(mode: .solo, requiredCategories: [.selfCultivation], phraseID: "byojo-shin-kore-do"),
        PhraseRule(mode: .solo, requiredCategories: [.celebration], phraseID: "shoju-sennen-no-midori"),

        PhraseRule(mode: nil, requiredCategories: [.celebration, .tranquility], phraseID: "shoju-sennen-no-midori"),
        PhraseRule(mode: nil, requiredCategories: [.hospitality, .resilience], phraseID: "koun-ryusui")
    ]
}

private struct PhraseRule {
    let mode: CeremonyMode?
    let requiredCategories: Set<CeremonyCategory>
    let phraseID: String
}
