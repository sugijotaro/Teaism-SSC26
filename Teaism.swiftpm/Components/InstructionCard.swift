import SwiftUI

struct InstructionCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
