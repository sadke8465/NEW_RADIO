import SwiftUI

// MARK: - Top Stations

struct TopStationsView: View {
    @EnvironmentObject var state: AppState
    @State private var stations: [Station] = []
    @State private var loading: Bool = false
    @State private var errorText: String? = nil

    var body: some View {
        ZStack {
            if loading && stations.isEmpty {
                LoadingView(text: "loading top stations…")
                    .transition(.opacity)
            } else if let e = errorText, stations.isEmpty {
                ErrorView(text: e, retry: { Task { await load() } })
                    .transition(.opacity)
            } else {
                StationList(stations: stations, emptyText: "no stations", persistKey: "stations")
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .task { if stations.isEmpty { await load() } }
        // A7: reload on request
        .onChange(of: state.reloadTick) { _, _ in
            if state.mode == .stations { Task { await load() } }
        }
    }

    private func load() async {
        loading = true
        defer {
            withAnimation(.snappy(duration: 0.25, extraBounce: 0.04)) { loading = false }
        }
        do {
            let result = try await RadioBrowserAPI.shared.topStations(limit: 100)
            withAnimation(.snappy(duration: 0.25, extraBounce: 0.04)) {
                stations = result
                errorText = nil
            }
        } catch {
            withAnimation(.snappy(duration: 0.25, extraBounce: 0.04)) {
                errorText = error.localizedDescription
            }
        }
    }
}

// MARK: - Search

struct SearchView: View {
    @EnvironmentObject var state: AppState
    @State private var query: String = ""
    @State private var results: [Station] = []
    @State private var loading: Bool = false
    @State private var errorText: String? = nil
    @State private var didRun: Bool = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("find")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("›")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                TextField("", text: $query, prompt: Text("station name…").foregroundColor(.secondary.opacity(0.6)))
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit { runSearch() }
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        didRun = false
                        fieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))

            Divider().opacity(0.18)

            ZStack {
                if loading {
                    LoadingView(text: "searching…")
                        .transition(.opacity)
                } else if let e = errorText {
                    ErrorView(text: e, retry: runSearch)
                        .transition(.opacity)
                } else if didRun {
                    StationList(stations: results, emptyText: "no results")
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                } else {
                    VStack(spacing: 6) {
                        Spacer()
                        Text("type and press ↵ to search")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("esc to clear  ·  S or / to focus")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.7))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
            }
        }
        .onAppear { fieldFocused = true }
        .onChange(of: state.focusSearchTick) { _, _ in
            fieldFocused = true
        }
        .onChange(of: state.escTick) { _, _ in
            if fieldFocused {
                if query.isEmpty {
                    fieldFocused = false
                } else {
                    query = ""
                }
            } else if !results.isEmpty || didRun {
                results = []
                didRun = false
                fieldFocused = true
            }
        }
        // A7: reload re-runs last search
        .onChange(of: state.reloadTick) { _, _ in
            if state.mode == .search && didRun { runSearch() }
        }
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        fieldFocused = false
        Task {
            withAnimation(.snappy(duration: 0.22)) { loading = true }
            errorText = nil
            defer { withAnimation(.snappy(duration: 0.22)) { loading = false } }
            do {
                let r = try await RadioBrowserAPI.shared.search(name: q)
                withAnimation(.snappy(duration: 0.22)) {
                    results = r
                    didRun = true
                }
            } catch {
                withAnimation(.snappy(duration: 0.22)) {
                    errorText = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Genres

struct GenresView: View {
    @EnvironmentObject var state: AppState
    @State private var tags: [RadioTag] = []
    @State private var stations: [Station] = []
    @State private var loading: Bool = false
    @State private var errorText: String? = nil

    var body: some View {
        Group {
            if let g = state.selectedGenre {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Button {
                            state.selectedGenre = nil
                            stations = []
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left").font(.system(size: 9, weight: .bold))
                                Text("tags")
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        Text("›")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(g)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04))
                    Divider().opacity(0.18)

                    ZStack {
                        if loading && stations.isEmpty {
                            LoadingView(text: "loading \(g)…")
                                .transition(.opacity)
                        } else if let e = errorText, stations.isEmpty {
                            ErrorView(text: e, retry: { Task { await loadStations(g) } })
                                .transition(.opacity)
                        } else {
                            StationList(stations: stations, emptyText: "no stations for \(g)",
                                        persistKey: "genre_stations")
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        }
                    }
                }
                .task(id: g) { await loadStations(g) }
            } else {
                TagList(tags: tags, loading: loading, errorText: errorText) { tag in
                    state.selectedGenre = tag.name
                } onRetry: {
                    Task { await loadTags() }
                }
                .task { if tags.isEmpty { await loadTags() } }
            }
        }
        .onChange(of: state.selectedGenre) { _, new in
            if new == nil { stations = [] }
        }
        // A7: reload
        .onChange(of: state.reloadTick) { _, _ in
            if state.mode == .genres {
                if let g = state.selectedGenre {
                    Task { await loadStations(g) }
                } else {
                    Task { await loadTags() }
                }
            }
        }
    }

    private func loadTags() async {
        loading = true; defer {
            withAnimation(.snappy(duration: 0.25, extraBounce: 0.04)) { loading = false }
        }
        do {
            let result = try await RadioBrowserAPI.shared.topTags(limit: 120)
            withAnimation(.snappy(duration: 0.25, extraBounce: 0.04)) {
                tags = result; errorText = nil
            }
        } catch {
            withAnimation(.snappy(duration: 0.25, extraBounce: 0.04)) {
                errorText = error.localizedDescription
            }
        }
    }

    private func loadStations(_ name: String) async {
        loading = true; defer {
            withAnimation(.snappy(duration: 0.25, extraBounce: 0.04)) { loading = false }
        }
        do {
            let result = try await RadioBrowserAPI.shared.stationsByTag(name)
            withAnimation(.snappy(duration: 0.25, extraBounce: 0.04)) {
                stations = result; errorText = nil
            }
        } catch {
            withAnimation(.snappy(duration: 0.25, extraBounce: 0.04)) {
                errorText = error.localizedDescription
            }
        }
    }
}

// MARK: - Tag List

struct TagList: View {
    let tags: [RadioTag]
    let loading: Bool
    let errorText: String?
    let onSelect: (RadioTag) -> Void
    let onRetry: () -> Void

    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: Int = 0
    @State private var gPressedAt: Date? = nil
    @FocusState private var focused: Bool

    /// B2: Namespace for selection highlight.
    @Namespace private var tagSelNS

    /// A2: Numeric count prefix buffer.
    @State private var countBuf = CountBuffer()

    /// B1: Staggered entrance.
    @State private var entranceRevealed: Bool = false

    var body: some View {
        Group {
            if loading && tags.isEmpty {
                LoadingView(text: "loading tags…")
                    .transition(.opacity)
            } else if let e = errorText, tags.isEmpty {
                ErrorView(text: e, retry: onRetry)
                    .transition(.opacity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(tags.enumerated()), id: \.element.id) { idx, t in
                                TagRow(name: t.name, count: t.stationcount,
                                       selected: idx == selection, selectionNS: tagSelNS)
                                    .id(idx)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selection = idx; onSelect(t) }
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
        .focusable()
        .focused($focused)
        .onAppear {
            focused = true
            // A5: restore selection
            if let saved = state.tabSelections["tags"] {
                selection = min(saved, max(0, tags.count - 1))
            }
            if !entranceRevealed { entranceRevealed = true }
        }
        .onChange(of: tags.count) { _, _ in
            entranceRevealed = false
            DispatchQueue.main.async { entranceRevealed = true }
        }
        // A5: persist selection
        .onChange(of: selection) { _, new in
            state.tabSelections["tags"] = new
        }
        .onKeyPress(phases: .down) { press in
            guard !state.showHelp, !tags.isEmpty else { return .ignored }

            // A2: accumulate digit presses
            if let digit = press.characters.first, digit.isNumber, press.modifiers.isEmpty {
                if !countBuf.buffer.isEmpty || digit != "0" {
                    countBuf.accumulate(digit)
                    state.flashStatus(countBuf.buffer)
                    return .handled
                }
            }

            let pageSize = max(5, min(15, tags.count / 5))

            switch press.key {
            case .downArrow:
                tagMove(+countBuf.consume()); return .handled
            case .upArrow:
                tagMove(-countBuf.consume()); return .handled
            case .rightArrow:
                countBuf.clear(); state.moveSection(+1); return .handled
            case .leftArrow:
                countBuf.clear(); state.moveSection(-1); return .handled
            case .return, .space:
                countBuf.clear(); onSelect(tags[selection]); return .handled
            case .pageDown:
                tagMove(+pageSize); return .handled
            case .pageUp:
                tagMove(-pageSize); return .handled
            default: break
            }

            // A1: Ctrl+d / Ctrl+u
            if press.modifiers.contains(.control) {
                let ch = press.characters.lowercased()
                if ch == "d" { tagMove(+pageSize); return .handled }
                if ch == "u" { tagMove(-pageSize); return .handled }
            }

            let c = press.characters.lowercased()
            switch c {
            case "j": tagMove(+countBuf.consume()); return .handled
            case "k": tagMove(-countBuf.consume()); return .handled
            case "g":
                countBuf.clear()
                if let t = gPressedAt, Date().timeIntervalSince(t) < 0.6 {
                    selection = 0
                    gPressedAt = nil
                } else {
                    gPressedAt = Date()
                }
                return .handled
            default: break
            }
            if press.characters == "G" {
                countBuf.clear(); selection = tags.count - 1; return .handled
            }
            return .ignored
        }
    }

    private func tagMove(_ delta: Int) {
        selection = max(0, min(tags.count - 1, selection + delta))
    }
}

// MARK: - Tag Row

private struct TagRow: View {
    let name: String
    let count: Int
    let selected: Bool
    var selectionNS: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            Text(selected ? "›" : " ")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(selected ? Color.accentColor : .clear)
                .frame(width: 10)
            Text(name)
                .font(.system(size: 12, weight: selected ? .semibold : .regular, design: .monospaced))
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            // B2: matchedGeometryEffect for selection highlight
            Group {
                if selected {
                    Color.primary.opacity(0.09)
                        .matchedGeometryEffect(id: "tagSelBg", in: selectionNS)
                } else {
                    Color.clear
                }
            }
        )
        .overlay(alignment: .leading) {
            if selected {
                Rectangle().fill(Color.accentColor).frame(width: 2)
                    .matchedGeometryEffect(id: "tagSelBar", in: selectionNS)
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.18, extraBounce: 0.03), value: selected)
    }
}

// MARK: - Favorites / Recents

struct FavoritesView: View {
    @EnvironmentObject var store: FavoritesStore
    var body: some View {
        StationList(stations: store.favorites,
                    emptyText: "no favorites yet — press f on a station",
                    persistKey: "favorites")
    }
}

struct RecentsView: View {
    @EnvironmentObject var store: FavoritesStore
    var body: some View {
        StationList(stations: store.recents, emptyText: "nothing played yet",
                    persistKey: "recents")
    }
}

// MARK: - Shared states

struct LoadingView: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            if reduceMotion {
                ProgressView().controlSize(.small)
            } else {
                LoadingDots()
            }
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .accessibilityValue(text)
    }
}

private struct LoadingDots: View {
    /// Phase velocity in radians per second for the sine wave that drives dot pulsing.
    private let animationSpeed: Double = 4.5
    /// Phase shift between neighboring dots to create a wave.
    private let phaseOffset: Double = 0.65
    /// Minimum dot opacity.
    private let baseOpacity: Double = 0.35
    /// Additional opacity applied at peak wave.
    private let opacityRange: Double = 0.65
    /// Dot diameter.
    private let dotSize: CGFloat = 5
    /// Minimum dot scale.
    private let baseScale: CGFloat = 0.75
    /// Additional scale applied at peak wave.
    private let scaleRange: CGFloat = 0.45

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = (t * animationSpeed) + (Double(i) * phaseOffset)
                    let wave = (sin(phase) + 1) / 2
                    Circle()
                        .fill(Color.accentColor.opacity(baseOpacity + (wave * opacityRange)))
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(baseScale + (wave * scaleRange))
                }
            }
            .frame(height: 10)
        }
        .accessibilityHidden(true)
    }
}

struct ErrorView: View {
    let text: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("retry", action: retry)
                .buttonStyle(.borderless)
                .font(.system(size: 11, design: .monospaced))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
