import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var player: AudioPlayer

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(player.isPlaying ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 7, height: 7)
                .animation(.easeInOut, value: player.isPlaying)

            Text("new_radio")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)

            Text(":\(state.mode.title)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer(minLength: 6)

            if !state.status.isEmpty {
                Text(state.status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .transition(.opacity)
            }

            Text("?")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                .onTapGesture { state.showHelp.toggle() }
                .help("Help (?)")
        }
        .animation(.easeInOut(duration: 0.15), value: state.status)
    }
}

struct TabStrip: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppMode.allCases) { m in
                tab(m)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func tab(_ m: AppMode) -> some View {
        let active = state.mode == m
        HStack(spacing: 4) {
            Text(m.key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(active ? .primary : .secondary)
                .opacity(active ? 0.9 : 0.55)
            Text(m.title)
                .font(.system(size: 11, weight: active ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(active ? .primary : .secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(active ? Color.primary.opacity(0.09) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(active ? Color.primary.opacity(0.18) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { state.switchMode(m) }
    }
}

struct NowPlayingBar: View {
    @EnvironmentObject var player: AudioPlayer
    @EnvironmentObject var store: FavoritesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: player.isPlaying
                      ? "dot.radiowaves.left.and.right"
                      : (player.current == nil ? "radio" : "pause.fill"))
                    .font(.system(size: 11))
                    .foregroundStyle(player.isPlaying ? Color.green : .secondary)
                    .frame(width: 14)

                if let c = player.current {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        if !c.subtitle.isEmpty {
                            Text(c.subtitle)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("nothing playing")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                if let c = player.current, store.isFavorite(c) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                }

                if player.isBuffering {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                }

                VolumeGauge(value: player.volume)
            }
            HintsBar()
        }
    }
}

private struct VolumeGauge: View {
    let value: Float
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: value == 0 ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule().fill(Color.secondary.opacity(0.65))
                        .frame(width: max(0, CGFloat(value) * geo.size.width))
                }
            }
            .frame(width: 42, height: 3)
        }
    }
}

private struct HintsBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            hint("j/k", "move")
            hint("↵", "play")
            hint("s", "star")
            hint("/", "find")
            hint("?", "help")
            Spacer(minLength: 0)
            hint("esc", "back")
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary.opacity(0.75))
    }

    @ViewBuilder
    private func hint(_ k: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(k)
                .padding(.horizontal, 3)
                .padding(.vertical, 0.5)
                .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 3))
            Text(label)
                .foregroundStyle(.secondary.opacity(0.7))
        }
    }
}

struct HelpOverlay: View {
    @EnvironmentObject var state: AppState

    private let rows: [(String, String)] = [
        ("1 … 5", "switch tab"),
        ("j / ↓", "move down"),
        ("k / ↑", "move up"),
        ("g / G", "top / bottom"),
        ("↵ / space", "play selected"),
        ("p", "play / pause"),
        (".", "stop"),
        ("s", "star selected"),
        ("S", "star current"),
        ("/", "search"),
        ("− / =", "volume down / up"),
        ("esc", "close / clear"),
        ("?", "toggle help"),
        ("⌘W / ⌘Q", "close / quit")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .onTapGesture { state.showHelp = false }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("keybindings")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Spacer()
                    Text("? / esc to close")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Divider().opacity(0.3)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(rows, id: \.0) { r in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(r.0)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .frame(width: 74, alignment: .leading)
                                .foregroundStyle(.primary)
                            Text(r.1)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .padding(22)
        }
    }
}
