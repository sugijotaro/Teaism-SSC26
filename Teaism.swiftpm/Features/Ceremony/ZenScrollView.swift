import SwiftUI

struct ZenScrollView: View {
    let phrase: ZenPhrase
    let selectedKeywords: [String]
    var showsHangingScroll: Bool = true

    var body: some View {
        VStack(spacing: 18) {
            if showsHangingScroll {
                ZenHangingScroll(
                    zenPhrase: phrase,
                    width: 230
                )
            }

            phraseMeaningCard
        }
        .padding(20)
    }

    private var phraseMeaningCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(phrase.phrase)
                .font(.title3.weight(.semibold))

            Text(phrase.reading)
                .font(.headline)

            Text(phrase.translation)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .overlay(.black.opacity(0.12))

            Text(phrase.meaning)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.primary)

            if !selectedKeywords.isEmpty {
                Divider()
                    .overlay(.black.opacity(0.12))

                Text("Selected intentions: \(selectedKeywords.joined(separator: " / "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.95, green: 0.92, blue: 0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ZenHangingScroll: View {
    let zenPhrase: ZenPhrase
    var width: CGFloat = 200

    private let imageAspectRatio: CGFloat = 3.0 / 4.0

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.27, green: 0.20, blue: 0.14))
                .frame(width: width + 28, height: 12)

            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(red: 0.93, green: 0.90, blue: 0.83))

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.black.opacity(0.14), lineWidth: 1)

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(red: 0.60, green: 0.56, blue: 0.49))
                        .frame(height: imageHeight * 0.19)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color(red: 0.60, green: 0.56, blue: 0.49))
                        .frame(height: imageHeight * 0.17)
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Group {
                    Image(resolvedImageAssetName)
                        .resizable()
                        .scaledToFill()
                }
                .padding(.vertical, imageHeight * 0.20)
                .padding(.horizontal, 10)
            }
            .frame(width: width, height: imageHeight)
            .padding(.top, 6)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.27, green: 0.20, blue: 0.14))
                .frame(width: width + 20, height: 14)
                .padding(.top, 6)
        }
        .shadow(color: .black.opacity(0.26), radius: 10, x: 0, y: 6)
    }

    private var imageHeight: CGFloat {
        width / imageAspectRatio
    }

    private var resolvedImageAssetName: String {
        zenPhrase.scrollImageAssetName
    }
}

#Preview("Zen Scroll") {
    ZStack {
        TeaRoomBackground(scene: .tokonomaWithout)
        ZenScrollView(
            phrase: CeremonyCatalog.defaultPhrase,
            selectedKeywords: []
        )
        .frame(maxWidth: 520)
        .padding(.horizontal, 24)
    }
}

#Preview("Zen Scroll with Keywords") {
    ZStack {
        TeaRoomBackground(scene: .tokonoma)
        ZenScrollView(
            phrase: CeremonyCatalog.defaultPhrase,
            selectedKeywords: ["Gratitude", "Harmony", "New Encounter"]
        )
        .frame(maxWidth: 520)
        .padding(.horizontal, 24)
    }
}
