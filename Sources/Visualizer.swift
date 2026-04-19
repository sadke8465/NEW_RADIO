import SwiftUI

// MARK: - Visualizer Settings & Presets

struct VisualizerPreset: Identifiable {
    let id = UUID()
    let name: String
    let smoothness: CGFloat
    let uniformity: CGFloat
    let sensitivity: CGFloat
    let scaleMultiplier: CGFloat
    let baseSize: CGFloat
    let spacing: CGFloat
    let yLimit: CGFloat
}

class VisualizerSettings: ObservableObject {
    @Published var smoothness: CGFloat      = 0.75
    @Published var uniformity: CGFloat      = 0.07
    @Published var sensitivity: CGFloat     = 0.11
    @Published var scaleMultiplier: CGFloat = 1.00
    @Published var baseSize: CGFloat        = 5.00
    @Published var spacing: CGFloat         = 12.50
    @Published var yOffsetMax: CGFloat      = 500.00
    @Published var currentPresetIndex: Int  = 0

    let colors: [Color] = [
        Color(red: 0.98, green: 0.25, blue: 0.65),
        Color(red: 0.55, green: 0.55, blue: 1.0),
        Color(red: 0.78, green: 0.85, blue: 0.20),
        Color(red: 1.0,  green: 0.45, blue: 0.35),
        Color(red: 0.92, green: 0.85, blue: 0.75),
        Color(red: 0.25, green: 0.75, blue: 0.50)
    ]

    static let presets: [VisualizerPreset] = [
        VisualizerPreset(
            name: "Pulsar Bloom",
            smoothness: 0.75, uniformity: 0.07, sensitivity: 0.11,
            scaleMultiplier: 1.00, baseSize: 5.00, spacing: 12.50, yLimit: 500
        ),
        VisualizerPreset(
            name: "Fixed Grow",
            smoothness: 0.70, uniformity: 0.00, sensitivity: 0.00,
            scaleMultiplier: 2.5, baseSize: 5.00, spacing: 17.00, yLimit: 500
        ),
        VisualizerPreset(
            name: "Kinetic Weave",
            smoothness: 0.70, uniformity: 0.055, sensitivity: 0.07,
            scaleMultiplier: 0.00, baseSize: 10.35, spacing: 12.75, yLimit: 500
        )
    ]

    var currentPresetName: String {
        Self.presets[currentPresetIndex].name
    }

    func apply(preset: VisualizerPreset) {
        withAnimation(.interpolatingSpring(stiffness: 100, damping: 20)) {
            smoothness      = preset.smoothness
            uniformity      = preset.uniformity
            sensitivity     = preset.sensitivity
            scaleMultiplier = preset.scaleMultiplier
            baseSize        = preset.baseSize
            spacing         = preset.spacing
            yOffsetMax      = preset.yLimit
        }
    }

    func cyclePreset() {
        currentPresetIndex = (currentPresetIndex + 1) % Self.presets.count
        apply(preset: Self.presets[currentPresetIndex])
    }
}

// MARK: - Visualizer View

struct VisualizerView: View {
    @ObservedObject var settings: VisualizerSettings

    /// This array of 6 amplitudes should be fed and smoothed by your audio engine / frame timer
    @Binding var displayAmplitudes: [CGFloat]

    private let panelBG = Color(red: 0.157, green: 0.157, blue: 0.157)

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    let presetSpring = Animation.interpolatingSpring(stiffness: 100, damping: 20)
                    HStack(spacing: settings.spacing) {
                        ForEach(0..<6, id: \.self) { i in
                            Circle()
                                .fill(settings.colors[i])
                                .frame(width: settings.baseSize, height: settings.baseSize)
                                .animation(presetSpring, value: settings.baseSize)
                                .scaleEffect(safeScale(i, geo.size.height))
                                .offset(y: safeOffset(i, geo.size.height))
                        }
                    }
                    .animation(presetSpring, value: settings.spacing)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(panelBG)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Visualizer Calculations

    private func safeScale(_ i: Int, _ h: CGFloat) -> CGFloat {
        let amp   = displayAmplitudes[i]
        let want  = 1.0 + sqrt(amp * settings.scaleMultiplier)
        let limit = (h * 0.8) / settings.baseSize
        return min(want, limit)
    }

    private func safeOffset(_ i: Int, _ h: CGFloat) -> CGFloat {
        let amp      = displayAmplitudes[i]
        let dir: CGFloat = (i % 2 == 0) ? -1 : 1
        let raw      = dir * (amp * settings.sensitivity * 10)
        let radius   = (settings.baseSize * safeScale(i, h)) / 2
        let winLimit = (h / 2) - radius - 10
        let finalLim = min(settings.yOffsetMax, winLimit)
        return max(min(raw, finalLim), -finalLim)
    }
}

// MARK: - Frame Smoothing Extension (Call this on a Timer/DisplayLink)
extension VisualizerView {
    /// Feed raw audio FFT output into this function at ~60-120hz to generate the smoothed `displayAmplitudes`
    static func calculateSmoothedAmplitudes(
        rawAmplitudes: [Float],
        currentDisplayAmplitudes: inout [CGFloat],
        settings: VisualizerSettings
    ) {
        let raw = rawAmplitudes.map { CGFloat($0) }
        let avg = raw.reduce(0, +) / CGFloat(raw.count)

        for i in 0..<6 {
            let mixed = raw[i] * (1 - settings.uniformity) + avg * settings.uniformity
            currentDisplayAmplitudes[i] += (mixed - currentDisplayAmplitudes[i]) * (1 - settings.smoothness)
        }
    }
}

// MARK: - Visualizer Driver (simulated audio-reactive animation)

/// Wraps `VisualizerView` with a `TimelineView` animation loop that generates
/// simulated audio-reactive amplitudes from layered sine waves when audio is playing.
struct VisualizerDriver: View {
    @ObservedObject var settings: VisualizerSettings
    let isPlaying: Bool
    let volume: Float
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            // Static dots at rest when motion is reduced.
            VisualizerView(
                settings: settings,
                displayAmplitudes: .constant(Array(repeating: CGFloat(0), count: 6))
            )
        } else {
            TimelineView(.animation) { ctx in
                let amps = amplitudes(at: ctx.date)
                VisualizerView(
                    settings: settings,
                    displayAmplitudes: .constant(amps)
                )
            }
        }
    }

    // MARK: - Simulated amplitude generation

    /// Frequencies (Hz) for each of the 6 channels – chosen to avoid obvious repetition.
    private static let freqs:  [Double] = [2.3, 3.1, 1.7, 4.2, 2.8, 3.7]
    /// Phase offsets per channel to de-correlate the waves.
    private static let phases: [Double] = [0.0, 1.2, 2.4, 0.8, 1.6, 3.0]

    private func amplitudes(at date: Date) -> [CGFloat] {
        guard isPlaying else {
            return Array(repeating: 0, count: 6)
        }
        let t = date.timeIntervalSinceReferenceDate
        // Ensure dots stay visible even at very low volume.
        let minimumVisualVolume: Float = 0.3
        let v = CGFloat(max(minimumVisualVolume, volume))

        return (0..<6).map { i in
            let f = Self.freqs[i]
            let p = Self.phases[i]
            let w1 = sin(t * f + p)
            let w2 = sin(t * f * 1.5 + p * 0.7)
            let w3 = sin(t * 0.5 + Double(i) * 0.8)
            let combined = (w1 * 0.5 + w2 * 0.3 + w3 * 0.2 + 1) / 2
            return CGFloat(combined) * v * 50
        }
    }
}
