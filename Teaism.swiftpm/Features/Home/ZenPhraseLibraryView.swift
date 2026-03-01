import SwiftUI

struct ZenPhraseLibraryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedPhrase: ZenPhrase?
    let onBack: () -> Void

    var body: some View {
        ZStack {
            TeaRoomBackground(scene: .tokonomaWithout)

            ScrollView {
                VStack(spacing: 16) {
                    headerCard

                    ForEach(CeremonyCatalog.zenPhrases) { phrase in
                        phraseCard(for: phrase)
                    }

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
        .overlay {
            if let selectedPhrase {
                selectedPhraseOverlay(for: selectedPhrase)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedPhrase?.id)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zen Scroll Library")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            Text("Browse the Zen phrases used in this ceremony.")
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func phraseCard(for phrase: ZenPhrase) -> some View {
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 14) {
                ZenHangingScroll(
                    zenPhrase: phrase,
                    width: 108
                )
                .frame(maxWidth: .infinity)

                phraseDetail(for: phrase)
            }
            .padding(16)
            .background(cardBackground)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onTapGesture {
                showExpandedScroll(for: phrase)
            }
        } else {
            HStack(alignment: .top, spacing: 18) {
                ZenHangingScroll(
                    zenPhrase: phrase,
                    width: 108
                )

                phraseDetail(for: phrase)
            }
            .padding(16)
            .background(cardBackground)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onTapGesture {
                showExpandedScroll(for: phrase)
            }
        }
    }

    private func phraseDetail(for phrase: ZenPhrase) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(phrase.phrase)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(phrase.reading)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.94))

            Text(phrase.translation)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))

            Divider()
                .overlay(.white.opacity(0.18))

            Text(phrase.meaning)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.black.opacity(0.36))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
    }

    private func selectedPhraseOverlay(for phrase: ZenPhrase) -> some View {
        ZStack {
            TeaRoomBackground(scene: .tokonomaWithout)

            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissExpandedScroll()
                }

            VStack(spacing: 18) {
                HStack {
                    Spacer()

                    Button(action: dismissExpandedScroll) {
                        Label("Close", systemImage: "xmark")
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
                    .padding(.top)
                }

                Spacer(minLength: 0)

                ZenHangingScroll(
                    zenPhrase: phrase,
                    width: expandedScrollWidth
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 30)
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)
        }
        .ignoresSafeArea()
    }

    private var expandedScrollWidth: CGFloat {
        horizontalSizeClass == .compact ? 220 : 320
    }

    private func showExpandedScroll(for phrase: ZenPhrase) {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedPhrase = phrase
        }
    }

    private func dismissExpandedScroll() {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedPhrase = nil
        }
    }
}

#Preview {
    ZenPhraseLibraryView(onBack: {})
}
