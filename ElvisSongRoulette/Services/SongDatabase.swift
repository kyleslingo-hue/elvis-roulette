import Foundation
import Observation

/// Localized matching matrix that maps emotional states, typed mood queries, and artist filters
/// to curated Elvis Presley & Lisa Marie Presley session records.
/// Supports over-the-air (OTA) catalog updates from GitHub without an App Store update.
@Observable
final class SongDatabase {
    private(set) var songs: [SongRecord]
    private(set) var lastUpdatedDescription: String = "Bundled"

    static let remoteURL = URL(
        string: "https://raw.githubusercontent.com/kyleslingo-hue/elvis-roulette/main/ElvisSongRoulette/Resources/elvis_sessions.json"
    )!

    private static var cacheFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("elvis_sessions_cache.json")
    }

    init(bundle: Bundle = .main) {
        if let cached = Self.loadSongs(fromFileURL: Self.cacheFileURL), !cached.isEmpty {
            self.songs = cached
            self.lastUpdatedDescription = "OTA Cached"
        } else {
            self.songs = Self.loadSongs(from: bundle)
        }
    }

    init(songs: [SongRecord]) {
        self.songs = songs
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
            let decoded = try JSONDecoder().decode([SongRecord].self, from: data)
            guard !decoded.isEmpty else { return false }

            let dir = Self.cacheFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: Self.cacheFileURL, options: .atomic)
            self.songs = decoded
            self.lastUpdatedDescription = "Updated just now"
            return true
        } catch {
            return false
        }
    }

    private static func loadSongs(fromFileURL url: URL) -> [SongRecord]? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SongRecord].self, from: data) else {
            return nil
        }
        return decoded
    }

    private static func loadSongs(from bundle: Bundle) -> [SongRecord] {
        guard let url = bundle.url(forResource: "elvis_sessions", withExtension: "json") else {
            assertionFailure("Missing elvis_sessions.json in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([SongRecord].self, from: data)
        } catch {
            assertionFailure("Failed to decode elvis_sessions.json: \(error)")
            return []
        }
    }

    /// Returns all songs matching the given mood, optional free-text query, and artist filter.
    func matchingSongs(
        mood: Mood?,
        query: String = "",
        artistFilter: ArtistFilter = .all
    ) -> [SongRecord] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let artistFiltered = songs.filter { artistFilter.matches(artistName: $0.artist) }

        let moodFiltered: [SongRecord]
        if let mood {
            moodFiltered = artistFiltered.filter { $0.moods.contains(mood) }
        } else {
            moodFiltered = artistFiltered
        }

        guard !trimmedQuery.isEmpty else {
            return moodFiltered
        }

        // First infer any moods from the typed query text
        let inferredMoods = Mood.allCases.filter { candidate in
            candidate.displayName.lowercased().contains(trimmedQuery) ||
            candidate.searchSynonyms.contains(where: { trimmedQuery.contains($0) || $0.contains(trimmedQuery) })
        }

        let textMatches = artistFiltered.filter { song in
            let matchesKeyword = song.keywords.contains { $0.lowercased().contains(trimmedQuery) }
            let matchesMeta = song.title.lowercased().contains(trimmedQuery)
                || song.era.lowercased().contains(trimmedQuery)
                || song.album.lowercased().contains(trimmedQuery)
                || song.session.location.lowercased().contains(trimmedQuery)
            let matchesInferredMood = !inferredMoods.isEmpty && song.moods.contains(where: { inferredMoods.contains($0) })
            return matchesKeyword || matchesMeta || matchesInferredMood
        }

        if let mood {
            let intersection = textMatches.filter { $0.moods.contains(mood) }
            return intersection.isEmpty ? textMatches : intersection
        }

        return textMatches
    }

    /// Picks a random matching track, avoiding immediate repeats when alternatives exist.
    func spin(
        mood: Mood?,
        query: String = "",
        artistFilter: ArtistFilter = .all,
        excludingID: String? = nil
    ) -> SongRecord? {
        var candidates = matchingSongs(mood: mood, query: query, artistFilter: artistFilter)

        // Graceful fallback if a typed query has no exact hits
        if candidates.isEmpty {
            candidates = matchingSongs(mood: mood, query: "", artistFilter: artistFilter)
        }
        if candidates.isEmpty {
            candidates = songs.filter { artistFilter.matches(artistName: $0.artist) }
        }
        guard !candidates.isEmpty else { return nil }

        if let excludingID, candidates.count > 1 {
            let filtered = candidates.filter { $0.id != excludingID }
            if let pick = filtered.randomElement() {
                return pick
            }
        }
        return candidates.randomElement()
    }
}
