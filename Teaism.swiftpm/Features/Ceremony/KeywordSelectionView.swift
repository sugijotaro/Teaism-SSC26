import SwiftUI

struct KeywordSelectionView: View {
    let title: String
    let keywords: [CeremonyKeyword]
    let selected: Set<CeremonyKeyword>
    let isCentered: Bool
    let onToggle: (CeremonyKeyword) -> Void

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 130), spacing: 10)]
    }

    var body: some View {
        VStack(alignment: isCentered ? .center : .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(isCentered ? .center : .leading)
                .foregroundStyle(.white)

            LazyVGrid(columns: columns, alignment: isCentered ? .center : .leading, spacing: 10) {
                ForEach(keywords) { keyword in
                    keywordChip(keyword)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.16))
        )
    }

    @ViewBuilder
    private func keywordChip(_ keyword: CeremonyKeyword) -> some View {
        let isSelected = selected.contains(keyword)

        Button {
            onToggle(keyword)
        } label: {
            VStack(alignment: isCentered ? .center : .leading, spacing: 0) {
                Text(keyword.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(isCentered ? .center : .leading)
            }
            .foregroundStyle(isSelected ? Color.black : Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0 : 0.26), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
