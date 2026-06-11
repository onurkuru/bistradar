import Foundation
import Observation

// Loads feed.json from the CDN, caches it on disk, and falls back to the copy
// bundled at build time so the app always has data on first launch / offline.

@Observable
@MainActor
final class FeedService {
    // GitHub raw (Fastly CDN, ~5-min cache) — fresher than jsDelivr, whose @main
    // tag caches up to 12h. The repo is public, so no auth is needed.
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/onurkuru/bistradar/main/data/feed.json")!

    private(set) var feed: Feed = .empty
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastUpdated: Date?

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("feed.json")
    }()

    func loadInitial() {
        // Show cached/bundled data immediately, then refresh from network.
        if let cached = readLocal(cacheURL) ?? readBundled() {
            feed = cached
        }
        Task { await refresh() }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var req = URLRequest(url: Self.remoteURL)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(Feed.self, from: data)
            feed = decoded
            try? data.write(to: cacheURL)
            lastUpdated = FeedDate.parse(decoded.generatedAt)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func readLocal(_ url: URL) -> Feed? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Feed.self, from: data)
    }

    private func readBundled() -> Feed? {
        guard let url = Bundle.main.url(forResource: "feed", withExtension: "json") else { return nil }
        return readLocal(url)
    }
}
