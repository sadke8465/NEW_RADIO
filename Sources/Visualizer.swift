import SwiftUI

/// A small, organic-looking frequency-bar visualizer that animates while audio
/// is playing and smoothly settles to a flat line when paused or stopped.
///
/// Driven entirely by `TimelineView(.animation)` — no real FFT; instead it
/// layers several sine oscillators at different speeds and phase offsets per bar
/// to produce movement that *looks* like a live equalizer.
struct AudioVisualizer: View {
    let isPlaying: Bool

    /// Number of vertical bars.
    var barCount: Int = 24
    /// Maximum bar height in points.
    var maxHeight: CGFloat = 14
    /// Minimum bar height (rest state / paused).
    var minHeight: CGFloat = 1.5
    /// Width of each bar.
    var barWidth: CGFloat = 2.5
    /// Spacing between bars.
    var barSpacing: CGFloat = 1.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Smooth amplitude envelope so bars don't pop in/out.
    @State private var amplitude: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    let h = barHeight(index: i, time: t)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barFill(height: h))
                        .frame(width: barWidth, height: h)
                }
            }
            .frame(height: maxHeight)
        }
        .onChange(of: isPlaying) { _, playing in
            let anim: Animation = reduceMotion
                ? .linear(duration: 0.01)
                : .snappy(duration: 0.28, extraBounce: 0.06)
            withAnimation(anim) {
                amplitude = playing ? 1.0 : 0.0
            }
        }
        .onAppear {
            // No animation on first appear — just snap to the correct state.
            amplitude = isPlaying ? 1.0 : 0.0
        }
        .accessibilityHidden(true)
    }

    // MARK: - Per-bar height

    private func barHeight(index i: Int, time t: Double) -> CGFloat {
        guard amplitude > 0 else { return minHeight }

        let pos = Double(i) / Double(max(barCount - 1, 1))  // 0 … 1

        // Base amplitude curve: slight bass boost on left, mid presence, treble sparkle.
        let bass   = max(0, 1.0 - pos * 2.0) * 0.22
        let mid    = (1.0 - abs(pos - 0.45) * 2.0).clamped(to: 0...1) * 0.18
        let treble = max(0, pos - 0.55) * 0.15

        // Several oscillators at different speeds give organic, non-repeating movement.
        let o1 = sin(t * 2.1  + Double(i) * 0.55)           * 0.16
        let o2 = sin(t * 4.6  + Double(i) * 0.82 + 1.3)     * 0.14
        let o3 = sin(t * 7.3  + Double(i) * 0.35 + 2.7)     * 0.10
        let o4 = sin(t * 11.1 + Double(i) * 1.15 + 0.8)     * 0.07
        // A slower "swell" that moves the whole bar field up and down.
        let swell = sin(t * 0.9 + Double(i) * 0.12) * 0.08

        let raw = bass + mid + treble + o1 + o2 + o3 + o4 + swell + 0.40
        let clamped = raw.clamped(to: 0...1)

        let h = minHeight + CGFloat(clamped * amplitude) * (maxHeight - minHeight)
        return h
    }

    // MARK: - Color

    /// Bars are green-tinted at full height and fade to secondary at rest.
    private func barFill(height: CGFloat) -> some ShapeStyle {
        let ratio = (height - minHeight) / max(maxHeight - minHeight, 1)
        return Color.green.opacity(0.4 + Double(ratio) * 0.5)
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
