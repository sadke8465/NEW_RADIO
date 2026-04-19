import SwiftUI

/// Shared helper for accumulating vim-style numeric count prefixes (e.g. `5j`).
/// Used by both StationList and TagList.
struct CountBuffer {
    var buffer: String = ""
    var time: Date? = nil

    /// Append a digit. Returns the current buffer string (for flashing).
    mutating func accumulate(_ digit: Character) {
        if let t = time, Date().timeIntervalSince(t) > 0.8 { buffer = "" }
        buffer.append(digit)
        time = Date()
    }

    /// Read and reset the count. Returns 1 when empty/expired.
    mutating func consume() -> Int {
        if let t = time, Date().timeIntervalSince(t) > 0.8 { buffer = ""; time = nil }
        let count = Int(buffer) ?? 1
        buffer = ""; time = nil
        return max(1, count)
    }

    mutating func clear() { buffer = ""; time = nil }
}

/// A keyboard-navigable list of stations. Owns selection and handles j/k/enter/f.
/// Global shortcuts are not handled here — they live in ContentView.
struct StationList: View {
    let stations: [Station]
    var emptyText: String = "no stations"
    var showsIndex: Bool = true
    /// A5: When set, selection is persisted in AppState across tab switches.
    var persistKey: String? = nil

    @EnvironmentObject var state: AppState
    @EnvironmentObject var player: AudioPlayer
    @EnvironmentObject var store: FavoritesStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: Int = 0
    @State private var gPressedAt: Date? = nil
    @FocusState private var focused: Bool

    /// B2: Namespace for selection highlight matchedGeometryEffect.
    @Namespace private var selectionNS

    /// A2: Numeric count prefix buffer.
    @State private var countBuf = CountBuffer()

    /// A3: Inline filter.
    @State private var filterActive: Bool = false
    @State private var filterText: String = ""
    @FocusState private var filterFocused: Bool

    /// B1: Staggered entrance.
    @State private var entranceRevealed: Bool = false

    /// The list actually shown — filtered when a filter is active.
    private var displayStations: [Station] {
        if filterText.isEmpty { return stations }
        let q = filterText.lowercased()
        return stations.filter { $0.name.lowercased().contains(q) }
    }

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
                VStack(spacing: 0) {
                    // A3: Filter bar
                    if filterActive {
                        HStack(spacing: 6) {
                            Text("filter")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("›")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                            TextField("", text: $filterText,
                                      prompt: Text("type to filter…")
                                        .foregroundColor(.secondary.opacity(0.6)))
                                .font(.system(size: 12, design: .monospaced))
                                .textFieldStyle(.plain)
                                .focused($filterFocused)
                                .onSubmit {
                                    filterFocused = false
                                    focused = true
                                }
                            if !filterText.isEmpty {
                                Text("\(displayStations.count)/\(stations.count)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04))
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                let ds = displayStations
                                ForEach(Array(ds.enumerated()), id: \.element.id) { idx, st in
                                    StationRow(
                                        index: idx,
                                        station: st,
                                        selected: idx == selection,
                                        playing: player.current?.id == st.id && player.isPlaying,
                                        favorite: store.isFavorite(st),
                                        showsIndex: showsIndex,
                                        selectionNS: selectionNS
                                    )
                                    .id(idx)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) { play(idx) }
                                    .onTapGesture { selection = idx }
                                    // B1: staggered entrance
                                    .opacity(entranceRevealed ? 1 : 0)
                                    .offset(y: entranceRevealed ? 0 : 4)
                                    .animation(
                                        reduceMotion ? .linear(duration: 0.01) :
                                            .snappy(duration: 0.25, extraBounce: 0.02)
                                            .delay(Double(min(idx, 15)) * 0.018),
                                        value: entranceRevealed
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onChange(of: selection) { old, new in
                            let distance = abs(new - old)
                            let animation: Animation = reduceMotion
                                ? .linear(duration: 0.01)
                                : (distance > 8
                                    ? .interpolatingSpring(stiffness: 330, damping: 38)
                                    : .snappy(duration: 0.16, extraBounce: 0.04))
                            withAnimation(animation) {
                                proxy.scrollTo(new, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .focusable()
        .focused($focused)
        .onAppear {
            focused = true
            // A5: Restore persisted selection
            if let key = persistKey, let saved = state.tabSelections[key] {
                selection = min(saved, max(0, stations.count - 1))
            } else if selection >= stations.count {
                selection = 0
            }
            // B1: trigger entrance
            if !entranceRevealed { entranceRevealed = true }
        }
        .onChange(of: stations.count) { _, _ in
            if selection >= displayStations.count {
                selection = max(0, displayStations.count - 1)
            }
            // B1: re-trigger entrance on data change
            entranceRevealed = false
            DispatchQueue.main.async { entranceRevealed = true }
        }
        // A5: persist selection changes
        .onChange(of: selection) { _, new in
            if let key = persistKey { state.tabSelections[key] = new }
        }
        // A3: clamp selection when filter narrows
        .onChange(of: filterText) { _, _ in
            let ds = displayStations
            if selection >= ds.count { selection = max(0, ds.count - 1) }
        }
        // A3: clear filter on tab change
        .onChange(of: state.mode) { _, _ in
            filterText = ""
            filterActive = false
        }
        // A3: clear filter on escape
        .onChange(of: state.escTick) { _, _ in
            if filterActive {
                filterText = ""
                filterActive = false
                focused = true
            }
        }
        .onKeyPress(phases: .down) { press in
            handle(press)
        }
        .animation(reduceMotion ? .linear(duration: 0.01)
                   : .snappy(duration: 0.2, extraBounce: 0.04), value: filterActive)
    }

    // MARK: - Key handling

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard !state.showHelp, !stations.isEmpty else { return .ignored }
        let ds = displayStations
        guard !ds.isEmpty else { return .ignored }

        // A2: accumulate digit presses into count buffer
        if let digit = press.characters.first, digit.isNumber, press.modifiers.isEmpty {
            if !countBuf.buffer.isEmpty || digit != "0" {
                countBuf.accumulate(digit)
                state.flashStatus(countBuf.buffer)
                return .handled
            }
        }

        let pageSize = max(5, min(15, ds.count / 5))

        switch press.key {
        case .downArrow:
            move(+countBuf.consume(), in: ds); return .handled
        case .upArrow:
            move(-countBuf.consume(), in: ds); return .handled
        case .rightArrow:
            countBuf.clear(); state.moveSection(+1); return .handled
        case .leftArrow:
            countBuf.clear(); state.moveSection(-1); return .handled
        case .return, .space:
            countBuf.clear(); play(selection, in: ds); return .handled
        // A1: hardware page keys
        case .pageDown:
            move(+pageSize, in: ds); return .handled
        case .pageUp:
            move(-pageSize, in: ds); return .handled
        default:
            break
        }

        // A1: Ctrl+d / Ctrl+u for half-page
        if press.modifiers.contains(.control) {
            let c = press.characters.lowercased()
            if c == "d" { move(+pageSize, in: ds); return .handled }
            if c == "u" { move(-pageSize, in: ds); return .handled }
        }

        let c = press.characters.lowercased()
        switch c {
        case "j": move(+countBuf.consume(), in: ds); return .handled
        case "k": move(-countBuf.consume(), in: ds); return .handled
        case "g":
            countBuf.clear()
            if let t = gPressedAt, Date().timeIntervalSince(t) < 0.6 {
                selection = 0
                gPressedAt = nil
            } else {
                gPressedAt = Date()
            }
            return .handled
        case "f":
            countBuf.clear()
            let st = ds[selection]
            store.toggleFavorite(st)
            state.flashStatus(store.isFavorite(st) ? "starred" : "unstarred")
            return .handled
        default: break
        }
        if press.characters == "G" {
            countBuf.clear(); selection = ds.count - 1; return .handled
        }
        // A3: activate inline filter with /  (not in search mode)
        if press.characters == "/" && state.mode != .search {
            filterActive = true
            filterFocused = true
            return .handled
        }
        return .ignored
    }

    // MARK: - Helpers

    private func move(_ delta: Int, in ds: [Station]) {
        if ds.isEmpty { return }
        selection = max(0, min(ds.count - 1, selection + delta))
    }

    private func play(_ i: Int, in ds: [Station]) {
        guard ds.indices.contains(i) else { return }
        selection = i
        player.play(ds[i])
    }
}

// MARK: - Station Row

struct StationRow: View {
    let index: Int
    let station: Station
    let selected: Bool
    let playing: Bool
    let favorite: Bool
    let showsIndex: Bool
    /// B2: Namespace passed from parent StationList for selection highlight animation.
    var selectionNS: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            // B2: matchedGeometryEffect slides highlight between rows
            Group {
                if selected {
                    Color.primary.opacity(0.09)
                        .matchedGeometryEffect(id: "selBg", in: selectionNS)
                } else {
                    Color.clear
                }
            }
        )
        .overlay(alignment: .leading) {
            if selected {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
                    .matchedGeometryEffect(id: "selBar", in: selectionNS)
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.18, extraBounce: 0.03), value: selected)
        .animation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.22, extraBounce: 0.04), value: playing)
        .animation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.2, extraBounce: 0.02), value: favorite)
    }
}
