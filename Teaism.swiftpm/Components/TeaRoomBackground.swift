import SwiftUI

struct TeaRoomBackground: View {
    enum Scene {
        case introduction
        case chanoma
        case tokonoma
        case tokonomaWithout
        case kissa

        var assetName: String {
            switch self {
            case .introduction:
                return "bg_intro"
            case .chanoma:
                return "bg_chanoma"
            case .tokonoma:
                return "bg_tokonoma"
            case .tokonomaWithout:
                return "bg_tokonoma_without"
            case .kissa:
                return "bg_chanoma_without"
            }
        }

        var overlayTopOpacity: CGFloat {
            switch self {
            case .introduction:
                return 0.26
            case .chanoma:
                return 0.30
            case .tokonoma, .tokonomaWithout:
                return 0.22
            case .kissa:
                return 0.24
            }
        }
    }

    var scene: Scene = .chanoma

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.black)
                .overlay {
                    backgroundImage(named: scene.assetName)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(scene.overlayTopOpacity),
                            Color.black.opacity(0.52)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay {
                    Color.black.opacity(0.10)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }

    private func backgroundImage(named assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
    }
}
