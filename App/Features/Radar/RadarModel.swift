import BEMBELKit
import CoreGraphics
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class RadarModel {
    private(set) var nowcast: Loadable<RadarNowcast> = .idle

    /// Index into `frames`, not a minute. The composite's steps are five
    /// minutes apart today; indexing by position means a product that changes
    /// its step does not silently skip frames.
    private(set) var playhead = 0
    private(set) var isPlaying = false

    /// Rendered frames, keyed by minute. Built once per load — painting 25
    /// images per loop would burn battery to redraw pixels that cannot change.
    private var images: [Int: CGImage] = [:]
    private var scheme: ColorScheme = .light
    private var ticker: Task<Void, Never>?

    /// One loop of the whole forecast takes about this long. Slow enough to
    /// follow a shower across the city, fast enough that the loop closes before
    /// attention does.
    private static let secondsPerFrame: Double = 0.28
    /// The pause on the last frame, so a loop reads as a loop rather than as a
    /// stutter back to the start.
    private static let loopPause: Double = 0.9

    var frames: [RadarFrame] { nowcast.value?.frames ?? [] }

    var currentFrame: RadarFrame? {
        guard frames.indices.contains(playhead) else { return nil }
        return frames[playhead]
    }

    var currentImage: CGImage? {
        currentFrame.flatMap { images[$0.minute] }
    }

    /// Playhead position along the timeline, 0…1. One frame means the head
    /// sits at the start rather than dividing by zero.
    var progress: Double {
        guard frames.count > 1 else { return 0 }
        return Double(playhead) / Double(frames.count - 1)
    }

    /// Minutes ahead of the composite at the playhead.
    var currentMinute: Int { currentFrame?.minute ?? 0 }

    func load(from provider: any RadarProviding, scheme: ColorScheme) async {
        // `scheme` means "the palette the current images were rendered with",
        // so it may only be set by something that then renders. Assigning it
        // before this guard broke that: a second appearance with a new scheme
        // recorded the palette and returned without repainting, and the
        // `repaint` that follows the scheme change then correctly concluded it
        // had nothing to do — leaving the frames in the old palette until the
        // next refresh. Already loaded means the frames are unchanged and only
        // the palette can have moved, which is exactly a repaint.
        guard !nowcast.hasLoaded else {
            repaint(for: scheme)
            return
        }
        self.scheme = scheme
        nowcast = .loading
        nowcast = await .result { try await provider.nowcast() }
        renderImages()
    }

    func refresh(from provider: any RadarProviding) async {
        pause()
        nowcast = .loading
        nowcast = await .result { try await provider.nowcast() }
        playhead = 0
        renderImages()
    }

    /// The map's colour scheme can change while the nowcast is on screen —
    /// system appearance switching at sunset is the ordinary case. The frames
    /// are unchanged; only their palette is.
    func repaint(for scheme: ColorScheme) {
        guard scheme != self.scheme else { return }
        self.scheme = scheme
        renderImages()
    }

    private func renderImages() {
        var rendered: [Int: CGImage] = [:]
        for frame in frames {
            if let image = RadarRainScale.image(for: frame, scheme: scheme) {
                rendered[frame.minute] = image
            }
        }
        images = rendered
    }

    // MARK: - Playback

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard frames.count > 1 else { return }
        isPlaying = true
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isPlaying else { return }
                let atEnd = self.playhead >= self.frames.count - 1
                try? await Task.sleep(for: .seconds(atEnd ? Self.loopPause : Self.secondsPerFrame))
                // `pause()` cancels this task, so cancellation is also the
                // "stopped while we were sleeping" check.
                guard !Task.isCancelled else { return }
                self.playhead = atEnd ? 0 : self.playhead + 1
            }
        }
    }

    func pause() {
        isPlaying = false
        ticker?.cancel()
        ticker = nil
    }

    /// Scrubbing stops playback: a user dragging the head is steering, and a
    /// timer fighting the finger for the same value is the worst of both.
    func scrub(to fraction: Double) {
        guard frames.count > 1 else { return }
        pause()
        let index = Int((fraction * Double(frames.count - 1)).rounded())
        playhead = min(max(index, 0), frames.count - 1)
    }

    func step(by delta: Int) {
        guard !frames.isEmpty else { return }
        pause()
        playhead = min(max(playhead + delta, 0), frames.count - 1)
    }
}
