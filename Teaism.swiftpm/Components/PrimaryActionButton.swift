import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    var subtitle: String?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(
                Capsule()
                    .fill(Color.brown.opacity(0.88))
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}
