import AVFoundation
import SwiftUI
import UIKit

struct VideoBackgroundView: UIViewControllerRepresentable {
    var videoURL: URL?
    var placeholderImageName: String?
    var onVideoStarted: (() -> Void)?
    var onVideoFinished: (() -> Void)?
    var onVideoNearEnd: (() -> Void)?
    var nearEndThreshold: TimeInterval = 1
    var shouldAutoplay: Bool = true
    var shouldLoop: Bool = true
    var restartToken: UUID?

    class Coordinator {
        var lastRestartToken: UUID?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> VideoBackgroundViewController {
        let controller = VideoBackgroundViewController(
            videoURL: videoURL,
            placeholderImageName: placeholderImageName,
            shouldAutoplay: shouldAutoplay,
            shouldLoop: shouldLoop,
            nearEndThreshold: nearEndThreshold
        )
        controller.onVideoStarted = onVideoStarted
        controller.onVideoFinished = onVideoFinished
        controller.onVideoNearEnd = onVideoNearEnd
        return controller
    }

    func updateUIViewController(_ uiViewController: VideoBackgroundViewController, context: Context) {
        uiViewController.onVideoStarted = onVideoStarted
        uiViewController.onVideoFinished = onVideoFinished
        uiViewController.onVideoNearEnd = onVideoNearEnd
        uiViewController.setNearEndThreshold(nearEndThreshold)
        uiViewController.setShouldAutoplay(shouldAutoplay)
        uiViewController.setShouldLoop(shouldLoop)

        guard let restartToken else { return }
        if context.coordinator.lastRestartToken != restartToken {
            context.coordinator.lastRestartToken = restartToken
            uiViewController.restartFromBeginning()
        }
    }
}

class VideoBackgroundViewController: UIViewController {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private let videoURL: URL?
    private let placeholderImageName: String?
    private var shouldAutoplay: Bool
    private var shouldLoop: Bool
    private var nearEndThreshold: TimeInterval
    private var videoStartedTriggered = false
    private var nearEndTriggered = false
    private var timeObserverToken: Any?
    private let imageView = UIImageView()
    var onVideoStarted: (() -> Void)?
    var onVideoFinished: (() -> Void)?
    var onVideoNearEnd: (() -> Void)?

    init(
        videoURL: URL?,
        placeholderImageName: String?,
        shouldAutoplay: Bool,
        shouldLoop: Bool,
        nearEndThreshold: TimeInterval
    ) {
        self.videoURL = videoURL
        self.placeholderImageName = placeholderImageName
        self.shouldAutoplay = shouldAutoplay
        self.shouldLoop = shouldLoop
        self.nearEndThreshold = nearEndThreshold
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        setupVideoPlayer()
        setupObservers()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    private func setupImageView() {
        guard let imageName = placeholderImageName, let image = UIImage(named: imageName) else { return }

        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupVideoPlayer() {
        guard let url = videoURL else { return }

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = false

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspectFill

        if let playerLayer = playerLayer {
            view.layer.addSublayer(playerLayer)
        }

        setupTimeObserver()

        if shouldAutoplay {
            player?.play()
        }
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func playerDidFinishPlaying() {
        DispatchQueue.main.async {
            self.onVideoFinished?()
        }

        guard shouldLoop else { return }

        videoStartedTriggered = false
        nearEndTriggered = false
        player?.seek(to: .zero)
        if shouldAutoplay {
            player?.play()
        }
    }

    @objc private func handleAppWillEnterForeground() {
        if shouldAutoplay {
            player?.play()
        }
    }

    func setShouldAutoplay(_ shouldAutoplay: Bool) {
        self.shouldAutoplay = shouldAutoplay
        if shouldAutoplay {
            player?.play()
        } else {
            player?.pause()
        }
    }

    func setShouldLoop(_ shouldLoop: Bool) {
        self.shouldLoop = shouldLoop
    }

    func setNearEndThreshold(_ nearEndThreshold: TimeInterval) {
        self.nearEndThreshold = nearEndThreshold
    }

    func restartFromBeginning() {
        guard let player else { return }
        videoStartedTriggered = false
        nearEndTriggered = false
        player.seek(to: .zero)
        player.play()
    }

    private func setupTimeObserver() {
        guard timeObserverToken == nil, let player else { return }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.handlePlaybackTime(time)
        }
    }

    private func handlePlaybackTime(_ time: CMTime) {
        let current = time.seconds
        guard current.isFinite else { return }

        if !videoStartedTriggered, current >= 0.05 {
            videoStartedTriggered = true
            onVideoStarted?()
        }

        guard !nearEndTriggered,
              let duration = player?.currentItem?.duration.seconds,
              duration.isFinite,
              duration > 0,
              nearEndThreshold > 0 else { return }

        let remaining = duration - current
        guard remaining <= nearEndThreshold, remaining >= 0 else { return }

        nearEndTriggered = true
        onVideoNearEnd?()
    }

    deinit {
        MainActor.assumeIsolated {
            if let timeObserverToken {
                player?.removeTimeObserver(timeObserverToken)
            }
            NotificationCenter.default.removeObserver(self)
        }
    }
}
