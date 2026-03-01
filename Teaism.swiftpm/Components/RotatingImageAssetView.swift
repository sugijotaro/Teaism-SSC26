import SwiftUI
import Combine

struct RotatingImageAssetView: View {
    let imageAssetNames: [String]
    let aspectRatio: CGFloat
    let rotationInterval: TimeInterval
    let blendDuration: TimeInterval

    @State private var baseImageIndex = 0
    @State private var overlayImageIndex = 0
    @State private var overlayOpacity = 0.0
    @State private var isTransitioning = false

    private let rotationTimer: Publishers.Autoconnect<Timer.TimerPublisher>

    init(
        imageAssetNames: [String],
        aspectRatio: CGFloat,
        rotationInterval: TimeInterval = 2.0,
        blendDuration: TimeInterval = 0.45
    ) {
        self.imageAssetNames = imageAssetNames
        self.aspectRatio = aspectRatio
        self.rotationInterval = rotationInterval
        self.blendDuration = blendDuration
        self.rotationTimer = Timer.publish(every: rotationInterval, on: .main, in: .common).autoconnect()
    }

    var body: some View {
        Group {
            if imageAssetNames.isEmpty {
                Color.clear
            } else {
                ZStack {
                    image(assetName: currentBaseImageAssetName)

                    image(assetName: currentOverlayImageAssetName)
                        .opacity(overlayOpacity)
                }
                .onReceive(rotationTimer) { _ in
                    rotateIfNeeded()
                }
            }
        }
    }

    private var currentBaseImageAssetName: String {
        imageAssetNames[baseImageIndex % imageAssetNames.count]
    }

    private var currentOverlayImageAssetName: String {
        imageAssetNames[overlayImageIndex % imageAssetNames.count]
    }

    private func image(assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .clipped()
            .aspectRatio(aspectRatio, contentMode: .fill)
    }

    private func rotateIfNeeded() {
        guard imageAssetNames.count > 1 else { return }
        guard !isTransitioning else { return }

        let nextIndex = (baseImageIndex + 1) % imageAssetNames.count
        isTransitioning = true
        overlayImageIndex = nextIndex
        overlayOpacity = 0

        withAnimation(.easeInOut(duration: blendDuration)) {
            overlayOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + blendDuration) {
            guard isTransitioning else { return }
            baseImageIndex = nextIndex

            withAnimation(.easeInOut(duration: blendDuration)) {
                overlayOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + blendDuration) {
                isTransitioning = false
            }
        }
    }
}
