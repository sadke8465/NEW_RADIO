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
            } else if let e = errorText, stations.isEmpty {
                ErrorView(text: e, retry: { Task { await load() } })
            } else {
                StationList(stations: stations, emptyText: "no stations")
            }
        }
        .task { if stations.isEmpty { await load() } }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            stations = try await RadioBrowserAPI.shared.topStations(limit: 100)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
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
                    .foregroundStyle(.accentColor)
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

            if loading {
                LoadingView(text: "searching…")
            } else if let e = errorText {
                ErrorView(text: e, retry: runSearch)
            } else if didRun {
                StationList(stations: results, emptyText: "no results")
            } else {
                VStack(spacing: 6) {
                    Spacer()
                    Text("type and press ↵ to search")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("esc to clear  ·  / to refocus")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        fieldFocused = false
        Task {
            loading = true
            errorText = nil
            defer { loading = false }
            do {
                results = try await RadioBrowserAPI.shared.search(name: q)
                didRun = true
            } catch {
                errorText = error.localizedDescription
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

                    if loading && stations.isEmpty {
                        LoadingView(text: "loading \(g)…")
                    } else if let e = errorText, stations.isEmpty {
                        ErrorView(text: e, retry: { Task { await loadStations(g) } })
                    } else {
                        StationList(stations: stations, emptyText: "no stations for \(g)")
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
    }

    private func loadTags() async {
        loading = true; defer { loading = false }
        do { tags = try await RadioBrowserAPI.shared.topTags(limit: 120); errorText = nil }
        catch { errorText = error.localizedDescription }
    }

    private func loadStations(_ name: String) async {
        loading = true; defer { loading = false }
        do { stations = try await RadioBrowserAPI.shared.stationsByTag(name); errorText = nil }
        catch { errorText = error.localizedDescription }
    }
}

struct TagList: View {
    let tags: [RadioTag]
    let loading: Bool
    let errorText: String?
    let onSelect: (RadioTag) -> Void
    let onRetry: () -> Void

    @EnvironmentObject var state: AppState
    @State private var selection: Int = 0
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if loading && tags.isEmpty {
                LoadingView(text: "loading tags…")
            } else if let e = errorText, tags.isEmpty {
                ErrorView(text: e, retry: onRetry)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(tags.enumerated()), id: \.element.id) { idx, t in
                                TagRow(name: t.name, count: t.stationcount, selected: idx == selection)
                                    .id(idx)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selection = idx; onSelect(t) }
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
        .onAppear { focused = true }
        .onKeyPress(phases: .down) { press in
            guard !state.showHelp, !tags.isEmpty else { return .ignored }
            switch press.key {
            case .upArrow:    selection = max(0, selection - 1); return .handled
            case .downArrow:  selection = min(tags.count - 1, selection + 1); return .handled
            case .return, .space:
                onSelect(tags[selection]); return .handled
            default: break
            }
            let c = press.characters.lowercased()
            switch c {
            case "j": selection = min(tags.count - 1, selection + 1); return .handled
            case "k": selection = max(0, selection - 1); return .handled
            default: break
            }
            if press.characters == "G" { selection = tags.count - 1; return .handled }
            return .ignored
        }
    }
}

private struct TagRow: View {
    let name: String
    let count: Int
    let selected: Bool

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
        .background(selected ? Color.primary.opacity(0.09) : Color.clear)
        .overlay(alignment: .leading) {
            if selected {
                Rectangle().fill(Color.accentColor).frame(width: 2)
            }
        }
    }
}

// MARK: - Favorites / Recents

struct FavoritesView: View {
    @EnvironmentObject var store: FavoritesStore
    var body: some View {
        StationList(stations: store.favorites, emptyText: "no favorites yet — press s on a station")
    }
}

struct RecentsView: View {
    @EnvironmentObject var store: FavoritesStore
    var body: some View {
        StationList(stations: store.recents, emptyText: "nothing played yet")
    }
}

// MARK: - Shared states

struct LoadingView: View {
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView().controlSize(.small)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
