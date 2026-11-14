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

    private var player: AVPlayer?
    private var progressTimer: Timer?
    private var endObserver: NSObjectProtocol?

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
        resolvedTitle = nil
        resolvedAlbumTitle = nil
        artworkURL = nil
        previewURL = nil
        catalogURL = nil
        statusBanner = nil

        isLookingUp = true
        defer { isLookingUp = false }

        if authorizationStatus == .authorized {
            do {
                var request = MusicCatalogSearchRequest(
                    term: record.appleMusicQuery,
                    types: [Song.self]
                )
                request.limit = 3
                let response = try await request.response()
                if let match = response.songs.first {
                    resolvedSong = match
                    resolvedTitle = match.title
                    resolvedAlbumTitle = match.albumTitle
                    artworkURL = match.artwork?.url(width: 600, height: 600)
                    previewURL = match.previewAssets?.first?.url
                    catalogURL = match.url
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
            if resolvedSong == nil && previewURL == nil {
                await lookupCatalogSong(for: record)
            }

            // Try full Apple Music playback if authorized & subscribed
            if let song = resolvedSong,
               let subscription = try? await MusicSubscription.current,
               subscription.canPlayCatalogContent {
                do {
                    ApplicationMusicPlayer.shared.queue = [song]
                    try await ApplicationMusicPlayer.shared.play()
                    isPlayingPreview = true
                    statusBanner = nil
                    return
                } catch {
                    // Fall back to AVPlayer stream below
                }
            }

            guard let previewURL else {
                statusBanner = "No playable audio available for \(record.title)."
                return
            }

            startAVPlayer(url: previewURL)
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
            }
        }

        avPlayer.play()
        startProgressTimer()
    }

    private func fallbackITunesLookup(for record: SongRecord) async {
        guard let encoded = record.appleMusicQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=5&country=US") else {
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            let targetArtist = record.isLisaMarie ? "lisa marie" : "elvis"
            let match = decoded.results.first(where: {
                ($0.artistName ?? "").lowercased().contains(targetArtist) && $0.previewUrl != nil
            }) ?? decoded.results.first

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
        } catch {
            // Ignore network errors silently
        }
    }

    func stopPreview() {
        ApplicationMusicPlayer.shared.stop()
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
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal in simulator
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
}
