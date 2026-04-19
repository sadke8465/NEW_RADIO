import SwiftUI

/// A keyboard-navigable list of stations. Owns selection and handles j/k/enter/s.
/// Global shortcuts are not handled here — they live in ContentView.
struct StationList: View {
    let stations: [Station]
    var emptyText: String = "no stations"
    var showsIndex: Bool = true

    @EnvironmentObject var state: AppState
    @EnvironmentObject var player: AudioPlayer
    @EnvironmentObject var store: FavoritesStore

    @State private var selection: Int = 0
    @State private var gPressedAt: Date? = nil
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if stations.isEmpty {
                VStack {
                    Spacer()
                    Text(emptyText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(stations.enumerated()), id: \.element.id) { idx, st in
                                StationRow(
                                    index: idx,
                                    station: st,
                                    selected: idx == selection,
                                    playing: player.current?.id == st.id && player.isPlaying,
                                    favorite: store.isFavorite(st),
                                    showsIndex: showsIndex
                                )
                                .id(idx)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { play(idx) }
                                .onTapGesture { selection = idx }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selection) { _, new in
                        withAnimation(.easeInOut(duration: 0.08)) {
                            proxy.scrollTo(new, anchor: .center)
                        }
                    }
                }
            }
        }
        .focusable()
        .focused($focused)
        .onAppear {
            focused = true
            if selection >= stations.count { selection = 0 }
        }
        .onChange(of: stations.count) { _, _ in
            if selection >= stations.count { selection = max(0, stations.count - 1) }
        }
        .onKeyPress(phases: .down) { press in
            handle(press)
        }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard !state.showHelp, !stations.isEmpty else { return .ignored }
        switch press.key {
        case .downArrow:
            move(+1); return .handled
        case .upArrow:
            move(-1); return .handled
        case .return, .space:
            play(selection); return .handled
        default:
            break
        }

        let c = press.characters.lowercased()
        switch c {
        case "j": move(+1); return .handled
        case "k": move(-1); return .handled
        case "g":
            if let t = gPressedAt, Date().timeIntervalSince(t) < 0.6 {
                selection = 0
                gPressedAt = nil
            } else {
                gPressedAt = Date()
            }
            return .handled
        case "s":
            let st = stations[selection]
            store.toggleFavorite(st)
            state.flashStatus(store.isFavorite(st) ? "starred" : "unstarred")
            return .handled
        default: break
        }
        if press.characters == "G" {
            selection = stations.count - 1
            return .handled
        }
        return .ignored
    }

    private func move(_ delta: Int) {
        let next = selection + delta
        if stations.isEmpty { return }
        selection = max(0, min(stations.count - 1, next))
    }

    private func play(_ i: Int) {
        guard stations.indices.contains(i) else { return }
        selection = i
        player.play(stations[i])
    }
}

struct StationRow: View {
    let index: Int
    let station: Station
    let selected: Bool
    let playing: Bool
    let favorite: Bool
    let showsIndex: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // selection gutter
            Text(selected ? "›" : " ")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(selected ? Color.accentColor : .clear)
                .frame(width: 10, alignment: .center)

            if showsIndex {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.55))
                    .frame(width: 22, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    if playing {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                    }
                    Text(station.name.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                    if favorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                    }
                }
                if !station.subtitle.isEmpty {
                    Text(station.subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            selected
                ? Color.primary.opacity(0.09)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if selected {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
            }
        }
    }
}
