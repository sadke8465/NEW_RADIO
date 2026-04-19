import Foundation
import SwiftUI

enum AppMode: Int, CaseIterable, Identifiable {
    case stations, search, genres, favorites, recents

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .stations: return "top"
        case .search:   return "find"
        case .genres:   return "tags"
        case .favorites: return "stars"
        case .recents:  return "recent"
        }
    }

    var key: String {
        switch self {
        case .stations: return "1"
        case .search:   return "2"
        case .genres:   return "3"
        case .favorites: return "4"
        case .recents:  return "5"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var mode: AppMode = .stations
    @Published var showHelp: Bool = false
    @Published var selectedGenre: String? = nil
    @Published var status: String = ""

    // Counter-based signals for escape and search-focus requests.
    @Published var escTick: Int = 0
    @Published var focusSearchTick: Int = 0

    let player: AudioPlayer
    let store: FavoritesStore

    init() {
        let store = FavoritesStore()
        self.store = store
        self.player = AudioPlayer(onPlay: { [weak store] station in
            store?.addRecent(station)
        })
    }

    func switchMode(_ m: AppMode) {
        if m != .genres { selectedGenre = nil }
        mode = m
        showHelp = false
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

    func flashStatus(_ text: String) {
        status = text
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if status == text { status = "" }
        }
    }
}
