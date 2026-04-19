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

    // MARK: - Oscillator tuning

    /// Frequency-curve shape: where the "mid" band peaks (0 = left, 1 = right).
    private let midFrequencyPosition: Double = 0.45

    /// Each oscillator is (speed, per-bar phase spread, global phase offset, amplitude).
    private let oscillators: [(speed: Double, spread: Double, offset: Double, amp: Double)] = [
        (speed: 2.1,  spread: 0.55, offset: 0.0, amp: 0.16),   // slow base
        (speed: 4.6,  spread: 0.82, offset: 1.3, amp: 0.14),   // medium
        (speed: 7.3,  spread: 0.35, offset: 2.7, amp: 0.10),   // fast detail
        (speed: 11.1, spread: 1.15, offset: 0.8, amp: 0.07),   // shimmer
    ]
    /// A slower "swell" that raises/lowers the whole bar field.
    private let swellSpeed: Double = 0.9
    private let swellSpread: Double = 0.12
    private let swellAmp: Double = 0.08

    /// Static bar height used for the reduced-motion fallback.
    private let reducedMotionHeight: CGFloat = 8

    var body: some View {
        if reduceMotion {
            // Accessibility: show a static bar pattern instead of animating.
            staticBars
        } else {
            animatedBars
        }
    }

    // MARK: - Animated bars (default)

    private var animatedBars: some View {
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
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                amplitude = playing ? 1.0 : 0.0
            }
        }
        .onAppear {
            amplitude = isPlaying ? 1.0 : 0.0
        }
        .accessibilityHidden(true)
    }

    // MARK: - Static bars (reduced motion)

    private var staticBars: some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green.opacity(isPlaying ? 0.65 : 0.25))
                    .frame(width: barWidth, height: isPlaying ? reducedMotionHeight : minHeight)
            }
        }
        .frame(height: maxHeight)
        .animation(.linear(duration: 0.01), value: isPlaying)
        .accessibilityHidden(true)
    }

    // MARK: - Per-bar height

    private func barHeight(index i: Int, time t: Double) -> CGFloat {
        guard amplitude > 0 else { return minHeight }

        let pos = Double(i) / Double(max(barCount - 1, 1))  // 0 … 1

        // Base amplitude curve: slight bass boost on left, mid presence, treble sparkle.
        let bass   = max(0, 1.0 - pos * 2.0) * 0.22
        let mid    = (1.0 - abs(pos - midFrequencyPosition) * 2.0).clamped(to: 0...1) * 0.18
        let treble = max(0, pos - 0.55) * 0.15

        // Sum the oscillators for organic, non-repeating movement.
        var osc = 0.0
        for o in oscillators {
            osc += sin(t * o.speed + Double(i) * o.spread + o.offset) * o.amp
        }
        let swell = sin(t * swellSpeed + Double(i) * swellSpread) * swellAmp

        let raw = bass + mid + treble + osc + swell + 0.40
        let clamped = raw.clamped(to: 0...1)

        let h = minHeight + CGFloat(clamped * amplitude) * (maxHeight - minHeight)
        return h
    }

    // MARK: - Color

    /// Bars are green-tinted at full height and fade toward transparent at rest.
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
