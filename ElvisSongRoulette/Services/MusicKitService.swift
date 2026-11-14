import AVFoundation
import Foundation
import MusicKit
import Observation
import UIKit

/// Coordinates Apple Music authorization, catalog lookup, playing Elvis music,
/// library additions, and custom playlist generation.
@MainActor
@Observable
final class MusicKitService {
    var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    var resolvedSong: Song?
    var resolvedMetadata: AppleMusicMetadata?
    var resolvedTitle: String?
    var resolvedAlbumTitle: String?
    var artworkURL: URL?
    var previewURL: URL?
    var catalogURL: URL?

    var isLookingUp = false
    var isPlayingPreview = false
    var previewProgress: Double = 0
    var statusBanner: String?
    var isPerformingLibraryAction = false
    var onTrackFinished: (() -> Void)?

    private var player: AVPlayer?
    private var progressTimer: Timer?
    private var endObserver: NSObjectProtocol?
    private var isUsingApplicationMusicPlayer = false
    private var appPlayerMonitorTask: Task<Void, Never>?

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        if status == .authorized {
            statusBanner = "Connected to Apple Music."
        } else {
            statusBanner = "Apple Music access is \(statusLabel(for: status)). You can still explore all session histories."
        }
    }

    func lookupCatalogSong(for record: SongRecord) async {
        stopPreview()
        resolvedSong = nil
        resolvedMetadata = nil
        resolvedTitle = nil
        resolvedAlbumTitle = nil
        artworkURL = nil
        previewURL = nil
        catalogURL = nil
        statusBanner = nil

        guard record.isOnAppleMusic else {
            return
        }

        isLookingUp = true
        defer { isLookingUp = false }

        if authorizationStatus == .authorized {
            do {
                var request = MusicCatalogSearchRequest(
                    term: record.appleMusicQuery,
                    types: [Song.self]
                )
                request.limit = 10
                let response = try await request.response()
                if let match = response.songs.first(where: { Self.isMatchingSong(title: $0.title, artist: $0.artistName, for: record) }) {
                    resolvedSong = match
                    resolvedTitle = match.title
                    resolvedAlbumTitle = match.albumTitle
                    artworkURL = match.artwork?.url(width: 600, height: 600)
                    previewURL = match.previewAssets?.first?.url
                    catalogURL = match.url
                    resolvedMetadata = AppleMusicMetadata(
                        title: match.title,
                        artistName: match.artistName,
                        albumTitle: match.albumTitle,
                        releaseDate: match.releaseDate,
                        genres: match.genreNames.filter { !$0.isEmpty && $0.caseInsensitiveCompare("Music") != .orderedSame },
                        composerName: match.composerName,
                        editorialNotes: match.editorialNotes?.standard ?? match.editorialNotes?.short,
                        duration: match.duration,
                        trackNumber: match.trackNumber,
                        discNumber: match.discNumber,
                        isrc: match.isrc,
                        isFromMusicKit: true
                    )
                }
            } catch {
                // Fall back to public iTunes catalog lookup below (e.g., in Simulator without MusicKit signing)
            }
        }

        if artworkURL == nil || previewURL == nil {
            await fallbackITunesLookup(for: record)
        }
    }

    func togglePreview(for record: SongRecord) {
        if isPlayingPreview {
            stopPreview()
            return
        }

        Task {
            _ = await play(record: record)
        }
    }

    @discardableResult
    func play(record: SongRecord) async -> Bool {
        if resolvedSong == nil && previewURL == nil {
            await lookupCatalogSong(for: record)
        }

        #if !targetEnvironment(simulator)
        // Try full Apple Music playback on physical devices when authorized & subscribed
        if let song = resolvedSong,
           let subscription = try? await MusicSubscription.current,
           subscription.canPlayCatalogContent {
            do {
                ApplicationMusicPlayer.shared.queue = [song]
                try await ApplicationMusicPlayer.shared.play()
                isUsingApplicationMusicPlayer = true
                isPlayingPreview = true
                statusBanner = nil
                startApplicationPlayerMonitor()
                return true
            } catch {
                // Fall back to AVPlayer stream below
            }
        }
        #endif

        guard let previewURL else {
            statusBanner = "No playable audio available for \(record.title)."
            return false
        }

        startAVPlayer(url: previewURL)
        return true
    }

    private func startApplicationPlayerMonitor() {
        appPlayerMonitorTask?.cancel()
        appPlayerMonitorTask = Task { @MainActor [weak self] in
            var sawPlaying = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self, self.isUsingApplicationMusicPlayer else { break }
                let status = ApplicationMusicPlayer.shared.state.playbackStatus
                if status == .playing {
                    sawPlaying = true
                    if let duration = self.resolvedMetadata?.duration, duration > 0 {
                        let current = ApplicationMusicPlayer.shared.playbackTime
                        self.previewProgress = min(max(current / duration, 0), 1)
                    }
                } else if sawPlaying && status == .stopped {
                    self.stopPreview()
                    self.onTrackFinished?()
                    break
                }
            }
        }
    }

    private func startAVPlayer(url: URL) {
        configureAudioSession()
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        player = avPlayer
        previewProgress = 0
        isPlayingPreview = true

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stopPreview()
                self?.onTrackFinished?()
            }
        }

        avPlayer.play()
        startProgressTimer()
    }

    private func fallbackITunesLookup(for record: SongRecord) async {
        guard let encoded = record.appleMusicQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=10&country=US") else {
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            let match = decoded.results.first(where: {
                Self.isMatchingSong(title: $0.trackName ?? "", artist: $0.artistName ?? "", for: record) && $0.previewUrl != nil
            }) ?? decoded.results.first(where: {
                Self.isMatchingSong(title: $0.trackName ?? "", artist: $0.artistName ?? "", for: record)
            })

            guard let match else { return }
            if resolvedTitle == nil {
                resolvedTitle = match.trackName
            }
            if resolvedAlbumTitle == nil {
                resolvedAlbumTitle = match.collectionName
            }
            if artworkURL == nil, let art = match.artworkUrl100 {
                let highRes = art.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                artworkURL = URL(string: highRes)
            }
            if previewURL == nil, let prev = match.previewUrl {
                previewURL = URL(string: prev)
            }
            if catalogURL == nil, let trackView = match.trackViewUrl {
                catalogURL = URL(string: trackView)
            }
            if resolvedMetadata == nil {
                let parsedDate = match.releaseDate.flatMap { ISO8601DateFormatter().date(from: $0) }
                let genres = [match.primaryGenreName].compactMap { $0 }.filter { !$0.isEmpty && $0.caseInsensitiveCompare("Music") != .orderedSame }
                let duration = match.trackTimeMillis.map { TimeInterval($0) / 1000.0 }
                resolvedMetadata = AppleMusicMetadata(
                    title: match.trackName ?? record.title,
                    artistName: match.artistName ?? record.artist,
                    albumTitle: match.collectionName,
                    releaseDate: parsedDate,
                    genres: genres,
                    composerName: nil,
                    editorialNotes: nil,
                    duration: duration,
                    trackNumber: match.trackNumber,
                    discNumber: match.discNumber,
                    isrc: nil,
                    isFromMusicKit: false
                )
            }
        } catch {
            // Ignore network errors silently
        }
    }

    func stopPreview() {
        appPlayerMonitorTask?.cancel()
        appPlayerMonitorTask = nil
        if isUsingApplicationMusicPlayer {
            ApplicationMusicPlayer.shared.stop()
            isUsingApplicationMusicPlayer = false
        }
        player?.pause()
        player = nil
        progressTimer?.invalidate()
        progressTimer = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        isPlayingPreview = false
        previewProgress = 0
    }

    func addToLibrary(record: SongRecord) async {
        if authorizationStatus != .authorized {
            await requestAuthorization()
        }
        guard authorizationStatus == .authorized else { return }

        isPerformingLibraryAction = true
        defer { isPerformingLibraryAction = false }

        if resolvedSong == nil {
            await lookupCatalogSong(for: record)
        }

        guard let song = resolvedSong else {
            statusBanner = "Could not locate \"\(record.title)\" in the Apple Music catalog."
            return
        }

        do {
            try await MusicLibrary.shared.add(song)
            statusBanner = "Added \"\(record.title)\" to your Apple Music Library."
        } catch {
            statusBanner = "Could not add to library: \(error.localizedDescription)"
        }
    }

    func createPlaylist(name: String, description: String, records: [SongRecord]) async -> Bool {
        if authorizationStatus != .authorized {
            await requestAuthorization()
        }
        guard authorizationStatus == .authorized else { return false }

        isPerformingLibraryAction = true
        defer { isPerformingLibraryAction = false }

        var catalogSongs: [Song] = []
        for record in records {
            do {
                var request = MusicCatalogSearchRequest(
                    term: record.appleMusicQuery,
                    types: [Song.self]
                )
                request.limit = 1
                let response = try await request.response()
                if let song = response.songs.first {
                    catalogSongs.append(song)
                }
            } catch {
                continue
            }
        }

        guard !catalogSongs.isEmpty else {
            statusBanner = "No matching Apple Music tracks found to build the playlist."
            return false
        }

        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName = trimmedName.isEmpty ? "Elvis Song Roulette Mix" : trimmedName
            try await MusicLibrary.shared.createPlaylist(
                name: finalName,
                description: description,
                items: catalogSongs
            )
            statusBanner = "Created playlist \"\(finalName)\" with \(catalogSongs.count) tracks!"
            return true
        } catch {
            statusBanner = "Playlist creation failed: \(error.localizedDescription)"
            return false
        }
    }

    func openInAppleMusic(record: SongRecord) {
        if let catalogURL {
            UIApplication.shared.open(catalogURL)
            return
        }
        let encoded = record.appleMusicQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let deepLink = URL(string: "music://music.apple.com/search?term=\(encoded)") {
            UIApplication.shared.open(deepLink)
        }
    }

    private func configureAudioSession() {
        Task.detached(priority: .userInitiated) {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
            } catch {
                // Non-fatal in simulator
            }
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                let current = player.currentTime().seconds
                let duration = player.currentItem?.duration.seconds ?? 30
                if duration.isFinite && duration > 0 {
                    self.previewProgress = min(max(current / duration, 0), 1)
                }
            }
        }
    }

    private static func isMatchingSong(title: String, artist: String, for record: SongRecord) -> Bool {
        let targetArtist = record.isLisaMarie ? "lisa marie" : "elvis"
        guard artist.localizedCaseInsensitiveContains(targetArtist) else {
            return false
        }
        let candidateNorm = normalizeTitle(title)
        let recordNorm = normalizeTitle(record.title)
        guard !candidateNorm.isEmpty, !recordNorm.isEmpty else { return false }
        return candidateNorm == recordNorm
    }

    private static func normalizeTitle(_ raw: String) -> String {
        let stripped = raw.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
        return stripped.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func statusLabel(for status: MusicAuthorization.Status) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "not determined"
        @unknown default: return "unavailable"
        }
    }
}

struct AppleMusicMetadata: Equatable {
    let title: String
    let artistName: String
    let albumTitle: String?
    let releaseDate: Date?
    let genres: [String]
    let composerName: String?
    let editorialNotes: String?
    let duration: TimeInterval?
    let trackNumber: Int?
    let discNumber: Int?
    let isrc: String?
    let isFromMusicKit: Bool

    var releaseYear: Int? {
        guard let releaseDate else { return nil }
        return Calendar.current.component(.year, from: releaseDate)
    }

    var formattedReleaseDate: String? {
        guard let releaseDate else { return nil }
        return releaseDate.formatted(date: .long, time: .omitted)
    }

    var formattedDuration: String? {
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        let totalSeconds = Int(duration.rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    var trackPositionLabel: String? {
        switch (discNumber, trackNumber) {
        case let (disc?, track?) where disc > 1:
            return "Disc \(disc), Track \(track)"
        case let (_, track?):
            return "Track \(track)"
        default:
            return nil
        }
    }
}

private struct ITunesSearchResponse: Decodable {
    let results: [ITunesTrack]
}

private struct ITunesTrack: Decodable {
    let artistName: String?
    let trackName: String?
    let collectionName: String?
    let artworkUrl100: String?
    let previewUrl: String?
    let trackViewUrl: String?
    let releaseDate: String?
    let primaryGenreName: String?
    let trackTimeMillis: Int?
    let trackNumber: Int?
    let discNumber: Int?
}
