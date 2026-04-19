import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var current: Station?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isBuffering: Bool = false
    @Published var volume: Float = 0.75 { didSet { player?.volume = volume } }
    @Published private(set) var lastError: String?

    private var player: AVPlayer?
    private var itemObs: NSKeyValueObservation?
    private var rateObs: NSKeyValueObservation?

    private let onPlay: @MainActor (Station) -> Void

    init(onPlay: @escaping @MainActor (Station) -> Void) {
        self.onPlay = onPlay
    }

    func play(_ station: Station) {
        if current?.id == station.id {
            toggle()
            return
        }
        guard let url = station.streamURL else {
            lastError = "Bad URL"
            return
        }
        stopInternal()
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.volume = volume
        p.automaticallyWaitsToMinimizeStalling = true
        player = p
        current = station
        lastError = nil
        isBuffering = true
        isPlaying = true

        itemObs = item.observe(\.status, options: [.new]) { [weak self] it, _ in
            Task { @MainActor in
                guard let self = self else { return }
                if it.status == .failed {
                    self.lastError = it.error?.localizedDescription ?? "Playback failed"
                    self.isBuffering = false
                    self.isPlaying = false
                } else if it.status == .readyToPlay {
                    self.isBuffering = false
                }
            }
        }
        rateObs = p.observe(\.rate, options: [.new]) { [weak self] pl, _ in
            Task { @MainActor in
                self?.isPlaying = pl.rate > 0
            }
        }

        p.play()
        onPlay(station)
    }

    func toggle() {
        guard let p = player else { return }
        if p.rate > 0 {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }

    func stop() {
        stopInternal()
        current = nil
    }

    private func stopInternal() {
        player?.pause()
        itemObs?.invalidate(); itemObs = nil
        rateObs?.invalidate(); rateObs = nil
        player = nil
        isPlaying = false
        isBuffering = false
    }

    func bumpVolume(_ delta: Float) {
        volume = max(0, min(1, volume + delta))
    }
}
