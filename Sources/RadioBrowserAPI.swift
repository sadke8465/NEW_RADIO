import Foundation

struct Station: Identifiable, Hashable, Codable {
    let stationuuid: String
    let name: String
    let url: String
    let url_resolved: String?
    let tags: String?
    let country: String?
    let codec: String?
    let bitrate: Int?
    let favicon: String?

    var id: String { stationuuid }

    var streamURL: URL? {
        let candidate = (url_resolved?.isEmpty == false ? url_resolved! : url)
        return URL(string: candidate)
    }

    var displayTags: String {
        (tags ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " · ")
    }

    var subtitle: String {
        var parts: [String] = []
        if let c = country, !c.isEmpty { parts.append(c) }
        if let b = bitrate, b > 0 { parts.append("\(b)kbps") }
        let tg = displayTags
        if !tg.isEmpty { parts.append(tg) }
        return parts.joined(separator: " · ")
    }
}

struct RadioTag: Codable, Hashable, Identifiable {
    let name: String
    let stationcount: Int
    var id: String { name }
}

actor RadioBrowserAPI {
    static let shared = RadioBrowserAPI()

    // Radio-Browser has multiple mirrors. We pick one and retry others on failure.
    private let hosts = [
        "https://de1.api.radio-browser.info",
        "https://de2.api.radio-browser.info",
        "https://at1.api.radio-browser.info",
        "https://fr1.api.radio-browser.info",
        "https://nl1.api.radio-browser.info"
    ]

    private func fetch(_ path: String) async throws -> Data {
        var lastError: Error = URLError(.badServerResponse)
        for host in hosts.shuffled() {
            guard let url = URL(string: host + path) else { continue }
            var req = URLRequest(url: url, timeoutInterval: 10)
            req.setValue("NewRadio/1.0 (macOS SwiftUI)", forHTTPHeaderField: "User-Agent")
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    return data
                }
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    func topStations(limit: Int = 100) async throws -> [Station] {
        let data = try await fetch("/json/stations/topvote/\(limit)")
        return try decode(data)
    }

    func search(name: String, limit: Int = 80) async throws -> [Station] {
        let q = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let data = try await fetch(
            "/json/stations/search?name=\(q)&limit=\(limit)&hidebroken=true&order=votes&reverse=true"
        )
        return try decode(data)
    }

    func stationsByTag(_ tag: String, limit: Int = 80) async throws -> [Station] {
        let q = tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let data = try await fetch(
            "/json/stations/bytagexact/\(q)?limit=\(limit)&hidebroken=true&order=votes&reverse=true"
        )
        return try decode(data)
    }

    func topTags(limit: Int = 120) async throws -> [RadioTag] {
        let data = try await fetch(
            "/json/tags?order=stationcount&reverse=true&limit=\(limit)&hidebroken=true"
        )
        return try decode(data)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let dec = JSONDecoder()
        return try dec.decode(T.self, from: data)
    }
}
