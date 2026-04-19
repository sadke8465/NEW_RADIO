import Foundation
import Combine

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favorites: [Station] = []
    @Published private(set) var recents: [Station] = []

    private let favKey = "newradio.favorites.v1"
    private let recentKey = "newradio.recents.v1"
    private let maxRecents = 50

    init() { load() }

    func isFavorite(_ s: Station) -> Bool {
        favorites.contains { $0.id == s.id }
    }

    func toggleFavorite(_ s: Station) {
        if let idx = favorites.firstIndex(where: { $0.id == s.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(s, at: 0)
        }
        save()
    }

    func addRecent(_ s: Station) {
        recents.removeAll { $0.id == s.id }
        recents.insert(s, at: 0)
        if recents.count > maxRecents {
            recents = Array(recents.prefix(maxRecents))
        }
        save()
    }

    func clearRecents() {
        recents.removeAll()
        save()
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: favKey),
           let arr = try? JSONDecoder().decode([Station].self, from: data) {
            favorites = arr
        }
        if let data = d.data(forKey: recentKey),
           let arr = try? JSONDecoder().decode([Station].self, from: data) {
            recents = arr
        }
    }

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(favorites) {
            d.set(data, forKey: favKey)
        }
        if let data = try? JSONEncoder().encode(recents) {
            d.set(data, forKey: recentKey)
        }
    }
}
