import SwiftUI

struct AboutAppView: View {
    let onBack: () -> Void
    let onShowZenPhraseLibrary: () -> Void

    var body: some View {
        ZStack {
            TeaRoomBackground(scene: .chanoma)
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    aboutCard

                    Color.clear
                        .frame(height: 20)
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 20)
                .padding(.top, 86)
                .padding(.bottom, 26)
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: onBack) {
                Label("Back to Home", systemImage: "chevron.backward")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.32), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.26), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.leading, 16)
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("About this App")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                Text("This is the story and intention behind an app that connects the spirit of Zen with everyday tea moments.")
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(.white.opacity(0.9))
            }

            sectionDivider

            sectionBlock(title: "The Spirit of Zen, Steve Jobs, and My Journey") {
                paragraph("I spent nine years of my youth-three in kindergarten and six in middle and high school-at Buddhist institutions. My alma mater, Setagaya Gakuen, is a school deeply rooted in the teachings of Soto Zen. There, I practiced Zazen (seated meditation) weekly, learning to confront and find peace within my inner self.")

                paragraph("The school's guiding philosophy is **\"Think & Share.\"**")

                paragraph("This is an English translation of the Buddhist phrase \"Tenjou Tenge Yuiga Dokuson.\" Its true meaning is: \"I possess a unique and irreplaceable value, and so does every other person on this planet.\" It is a call to recognize our differences and coexist with mutual respect.")

                paragraph("This philosophy of individual empowerment encouraged me to dive deep into programming. It led me to become a winner of Apple's Swift Student Challenge 2020 during my first year of high school-an experience that showed me how technology can connect us to the world.")

                paragraph("Furthermore, I have long admired the late Steve Jobs. He was known to study and be influenced by Soto Zen, and that influence is often reflected in Apple's focus on simplicity and essence. Seeing that the Zen spirit that shaped my identity also inspired a visionary who changed the world is a source of great pride for me.")
            }

            sectionDivider

            sectionBlock(title: "Why Tea? Beyond the Walls of Zazen") {
                paragraph("While Shikantaza (the Zen practice of \"just sitting\") provided me with profound stillness, I hit a wall when I tried to \"share\" this experience with others.")

                paragraph("As the eldest of four brothers, I saw my family struggling through high-pressure seasons-my younger brothers preparing for entrance exams and navigating heavy school workloads. The air at home was often tense. I desperately wanted to share the \"inner peace\" I found in Zen with them, but I found it difficult to put into words. In the end, all I could do was silently brew a cup of tea or coffee and hand it to them.")

                paragraph("I realized that for many, Zazen feels inaccessible. People get caught up in the physical difficulty of the posture or the mental challenge of \"thinking of nothing\" and give up before experiencing its rewards. At the same time, I noticed the global \"Matcha\" craze. While I am glad to see it spread, it often feels like a superficial trend, leaving behind the deep spiritual essence and the \"heart\" of the Japanese Tea Ceremony.")

                paragraph("I began to wonder: How can I bring this experience of \"centering oneself\" into daily life in a natural way? The answer was waiting for me in Sado (The Way of Tea).")
            }

            sectionDivider

            sectionBlock(title: "The Power of a Cup: Lessons from Starbucks") {
                paragraph("For the past four years, I have worked at Starbucks. There, I have focused on \"Connection\"-pouring my heart into every cup to enrich the lives of the customers standing before me.")

                paragraph("It was through this experience that I had a revelation: both preparing a cup for my brothers and connecting with customers each day at Starbucks embody the very core of the Tea Ceremony. The spirit of Wakei Seijaku (Harmony, Respect, Purity, and Tranquility) and Ichiza Konryu (the shared creation of a singular moment between host and guest) does not require a traditional tearoom.")

                paragraph("The simple act of mindfully brewing a drink, making eye contact, and sharing that moment is where Zen truly lives. This essence-Teaism-can be practiced by anyone, anywhere, with any beverage.")
            }

            sectionDivider

            sectionBlock(title: "About the App: Teaism") {
                paragraph("This app is a guide to establishing a \"Modern Tearoom\" within your daily life.")

                paragraph("You don't need to master complex rituals. By simply preparing a drink and following the guide, you can begin a session to face yourself (Solo) or connect deeply with someone special (Pair).")

                paragraph("In our fast-paced digital age, it is vital to pause and focus on the warmth of a single cup. Through this app, I hope to bring a sense of peace and vitality to the daily lives of people around the world.")
            }

            sectionDivider

            sectionBlock(title: "Acknowledgements") {
                paragraph("I would like to express my deepest gratitude to the Ebara Hatakeyama Museum of Art for their generous support in providing the location and resources for the photography and videography within this app.")

                paragraph("The museum's founder, Issei Hatakeyama (also known by his tea name, Sokuo), lived by the spirit of \"Youshu Aigan\"-the belief that one should not monopolize beautiful art, but rather enjoy and cherish it together with everyone. This resonates deeply with my mission to \"Share Teaism.\"")

                paragraph("I am profoundly honored to have the opportunity to translate the \"Heart of Tea,\" which has been protected for generations, into a new digital form on iPad.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            content()
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(height: 1)
    }

    private func paragraph(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .lineSpacing(4)
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

}

#Preview {
    AboutAppView(
        onBack: {},
        onShowZenPhraseLibrary: {}
    )
}
