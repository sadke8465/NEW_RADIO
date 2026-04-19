import Foundation
import SwiftUI

enum AppMode: Int, CaseIterable, Identifiable {
    case stations, search, genres, favorites, recents

    var id: Int { rawValue }
    static let sectionModes: [AppMode] = [.stations, .genres, .favorites, .recents]
    static let allModes: [AppMode] = [.stations, .search, .genres, .favorites, .recents]

    var title: String {
        switch self {
        case .stations: return "top"
        case .search:   return "find"
        case .genres:   return "tags"
        case .favorites: return "stars"
        case .recents:  return "recent"
        }
    }

    var key: String? {
        switch self {
        case .stations: return "1"
        case .search:   return nil
        case .genres:   return "2"
        case .favorites: return "3"
        case .recents:  return "4"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let noModeShiftDirection = 0

    @Published var mode: AppMode = .stations
    @Published private(set) var modeShiftDirection: Int = AppState.noModeShiftDirection
    @Published var showHelp: Bool = false
    @Published var showVisualizer: Bool = false
    @Published var selectedGenre: String? = nil
    @Published var status: String = ""

    // Counter-based signals for escape and search-focus requests.
    @Published var escTick: Int = 0
    @Published var focusSearchTick: Int = 0

    /// A5: Per-tab selection persistence — keyed by a caller-chosen string.
    @Published var tabSelections: [String: Int] = [:]

    /// A7: Reload signal — views observe this to re-fetch their data.
    @Published var reloadTick: Int = 0

    let player: AudioPlayer
    let store: FavoritesStore
    let visualizerSettings = VisualizerSettings()

    init() {
        let store = FavoritesStore()
        self.store = store
        self.player = AudioPlayer(onPlay: { [weak store] station in
            store?.addRecent(station)
        })
    }

    func switchMode(_ m: AppMode) {
        let oldMode = mode
        showHelp = false
        // Direction relies on AppMode raw-value order matching UI tab order.
        if m == oldMode {
            modeShiftDirection = AppState.noModeShiftDirection
        } else {
            modeShiftDirection = m.rawValue >= oldMode.rawValue ? 1 : -1
        }
        if m != .genres { selectedGenre = nil }
        mode = m
    }

    func moveSection(_ delta: Int) {
        let sections = AppMode.sectionModes
        guard !sections.isEmpty else { return }
        let current = sections.firstIndex(of: mode) ?? 0
        let wrapped = ((current + delta) % sections.count + sections.count) % sections.count
        switchMode(sections[wrapped])
    }

    /// A4: Cycle through ALL modes including search.
    func moveSectionAll(_ delta: Int) {
        let all = AppMode.allModes
        guard !all.isEmpty else { return }
        let current = all.firstIndex(of: mode) ?? 0
        let wrapped = ((current + delta) % all.count + all.count) % all.count
        switchMode(all[wrapped])
    }

    func handleEscape() {
        if showHelp { showHelp = false; return }
        if mode == .genres, selectedGenre != nil {
            selectedGenre = nil
            return
        }
        // Let views react for their own escape (clear search etc.)
        escTick &+= 1
    }

    func requestSearchFocus() {
        showHelp = false
        switchMode(.search)
        focusSearchTick &+= 1
    }

    /// A7: Ask the current tab to reload its data.
    func requestReload() {
        reloadTick &+= 1
    }

    func flashStatus(_ text: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            status = text
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if status == text {
                withAnimation(.easeInOut(duration: 0.15)) {
                    status = ""
                }
            }
        }
    }
}
