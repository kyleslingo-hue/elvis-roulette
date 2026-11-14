import Foundation
import Observation

/// A Follow That Dream (FTD) collector label release, sourced from elvisoncd.com.
/// FTD releases are collector-only CDs/books and are not available on Apple Music.
struct FTDRelease: Codable, Identifiable, Hashable {
    let id: String
    let catalogNumber: String
    let title: String
    let releaseDate: String
    let releaseType: String
    let series: String
    let coverImageURL: String?
    let detailURL: String

    var imageURL: URL? {
        guard let coverImageURL else { return nil }
        return URL(string: coverImageURL)
    }

    var infoURL: URL? {
        URL(string: detailURL)
    }
}

/// Loads and filters the bundled FTD collector catalog (`ftd_catalog.json`),
/// with over-the-air (OTA) refresh support from GitHub.
@Observable
final class FTDCatalog {
    private(set) var releases: [FTDRelease]

    static let remoteURL = URL(
        string: "https://raw.githubusercontent.com/kyleslingo-hue/elvis-roulette/main/ElvisSongRoulette/Resources/ftd_catalog.json"
    )!

    private static var cacheFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ftd_catalog_cache.json")
    }

    init(bundle: Bundle = .main) {
        if FileManager.default.fileExists(atPath: Self.cacheFileURL.path),
           let data = try? Data(contentsOf: Self.cacheFileURL),
           let cached = try? JSONDecoder().decode([FTDRelease].self, from: data),
           !cached.isEmpty {
            self.releases = cached
        } else {
            self.releases = Self.loadReleases(from: bundle)
        }
    }

    @MainActor
    func refreshFromRemote() async -> Bool {
        do {
            var request = URLRequest(url: Self.remoteURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return false
            }
            let decoded = try JSONDecoder().decode([FTDRelease].self, from: data)
            guard !decoded.isEmpty else { return false }

            let dir = Self.cacheFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: Self.cacheFileURL, options: .atomic)
            self.releases = decoded
            return true
        } catch {
            return false
        }
    }

    var availableSeries: [String] {
        let unique = Set(releases.map(\.series))
        return unique.sorted()
    }

    func filtered(query: String, series: String?) -> [FTDRelease] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return releases.filter { release in
            let matchesSeries = series == nil || release.series == series
            guard matchesSeries else { return false }
            guard !trimmed.isEmpty else { return true }
            return release.title.lowercased().contains(trimmed)
                || release.catalogNumber.lowercased().contains(trimmed)
                || release.releaseDate.lowercased().contains(trimmed)
                || release.releaseType.lowercased().contains(trimmed)
        }
    }

    private static func loadReleases(from bundle: Bundle) -> [FTDRelease] {
        guard let url = bundle.url(forResource: "ftd_catalog", withExtension: "json") else {
            assertionFailure("Missing ftd_catalog.json in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([FTDRelease].self, from: data)
        } catch {
            assertionFailure("Failed to decode ftd_catalog.json: \(error)")
            return []
        }
    }
}
