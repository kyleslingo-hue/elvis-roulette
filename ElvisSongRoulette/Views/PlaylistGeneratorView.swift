import SwiftUI

/// Standalone mood-to-playlist generator with in-app Now Playing controls and Apple Music export.
struct PlaylistGeneratorView: View {
    let musicService: MusicKitService
    let database: SongDatabase

    @State private var feelingInput = ""
    @State private var trackCount = 15
    @State private var generatedTracks: [SongRecord] = []
    @State private var activeIndex: Int? = nil
    @State private var playlistName = "Elvis Mood Mix"
    @State private var savedToLibrary = false
    @State private var playbackTask: Task<Void, Never>?

    private let quickFeelings = ["Christmas", "Late Night", "Heartbroken", "High Energy", "Gospel", "Lisa Marie"]

    private var activeSong: SongRecord? {
        guard let activeIndex, generatedTracks.indices.contains(activeIndex) else { return nil }
        return generatedTracks[activeIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    feelingPromptCard

                    if let song = activeSong {
                        nowPlayingCard(song)
                    }

                    if !generatedTracks.isEmpty {
                        generatedPlaylistSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(RetroTheme.vinylBlack.ignoresSafeArea())
            .navigationTitle("Playlist Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var feelingPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW ARE YOU FEELING?")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(RetroTheme.vegasGold)

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(RetroTheme.vegasGold)
                TextField("e.g. heartbroken, christmas, late night, Vegas...", text: $feelingInput)
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.sunCream)
                    .submitLabel(.go)
                    .onSubmit { generatePlaylist() }

                if !feelingInput.isEmpty {
                    Button {
                        feelingInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(RetroTheme.mutedCream)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RetroTheme.vinylBlack.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RetroTheme.vegasGold.opacity(0.3), lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickFeelings, id: \.self) { label in
                        Button {
                            feelingInput = label
                            generatePlaylist()
                        } label: {
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    feelingInput.caseInsensitiveCompare(label) == .orderedSame
                                    ? RetroTheme.vinylBlack
                                    : RetroTheme.sunCream
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    feelingInput.caseInsensitiveCompare(label) == .orderedSame
                                    ? RetroTheme.vegasGold
                                    : RetroTheme.elevatedSurface
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                Picker("Songs", selection: $trackCount) {
                    Text("10 Songs").tag(10)
                    Text("15 Songs").tag(15)
                    Text("25 Songs").tag(25)
                }
                .pickerStyle(.segmented)

                Button {
                    generatePlaylist()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Generate")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RetroTheme.vegasGold)
                    .foregroundStyle(RetroTheme.vinylBlack)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(RetroTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RetroTheme.vegasGold.opacity(0.25), lineWidth: 1)
        )
    }

    private func nowPlayingCard(_ song: SongRecord) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Group {
                    if let artURL = musicService.artworkURL {
                        AsyncImage(url: artURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                placeholderArtwork
                            }
                        }
                    } else {
                        placeholderArtwork
                    }
                }
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(musicService.isPlayingPreview ? "NOW PLAYING" : "READY TO PLAY")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(RetroTheme.vegasGold)

                    Text(musicService.resolvedTitle ?? song.title)
                        .font(.headline)
                        .foregroundStyle(RetroTheme.sunCream)
                        .lineLimit(1)

                    Text("\(song.artist) • \(musicService.resolvedAlbumTitle ?? song.album)")
                        .font(.caption)
                        .foregroundStyle(RetroTheme.mutedCream)
                        .lineLimit(1)
                }

                Spacer()

                ProgressView()
                    .scaleEffect(0.75)
                    .tint(RetroTheme.vegasGold)
                    .frame(width: 18, height: 18)
                    .opacity(musicService.isLookingUp ? 1 : 0)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 5)
                    Capsule()
                        .fill(RetroTheme.vegasGold)
                        .frame(width: proxy.size.width * musicService.previewProgress, height: 5)
                }
            }
            .frame(height: 5)

            HStack(spacing: 28) {
                Button {
                    playPreviousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundStyle(canGoPrevious ? RetroTheme.sunCream : RetroTheme.mutedCream.opacity(0.35))
                }
                .disabled(!canGoPrevious)

                Button {
                    if musicService.isPlayingPreview {
                        playbackTask?.cancel()
                        musicService.stopPreview()
                    } else if let activeIndex {
                        playTrack(at: activeIndex)
                    }
                } label: {
                    Image(systemName: musicService.isPlayingPreview ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(RetroTheme.vinylBlack)
                        .frame(width: 48, height: 48)
                        .background(RetroTheme.vegasGold)
                        .clipShape(Circle())
                }

                Button {
                    playNextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundStyle(canGoNext ? RetroTheme.sunCream : RetroTheme.mutedCream.opacity(0.35))
                }
                .disabled(!canGoNext)
            }
        }
        .padding(16)
        .background(RetroTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RetroTheme.vegasGold.opacity(0.4), lineWidth: 1)
        )
    }

    private var generatedPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlistName)
                        .font(.headline)
                        .foregroundStyle(RetroTheme.sunCream)
                    Text("\(generatedTracks.count) tracks")
                        .font(.caption)
                        .foregroundStyle(RetroTheme.mutedCream)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    playTrack(at: 0)
                } label: {
                    Label("Play Playlist", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RetroTheme.vegasGold)
                        .foregroundStyle(RetroTheme.vinylBlack)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    Task {
                        savedToLibrary = await musicService.createPlaylist(
                            name: playlistName,
                            description: "Generated from feeling '\(feelingInput.isEmpty ? "Surprise Mix" : feelingInput)' in Elvis Song Roulette.",
                            records: generatedTracks
                        )
                    }
                } label: {
                    HStack(spacing: 6) {
                        if musicService.isPerformingLibraryAction {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(RetroTheme.vegasGold)
                        } else {
                            Image(systemName: savedToLibrary ? "checkmark" : "plus.square.on.square")
                        }
                        Text(savedToLibrary ? "Saved" : "Add to Library")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RetroTheme.elevatedSurface)
                    .foregroundStyle(RetroTheme.vegasGold)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(RetroTheme.vegasGold.opacity(0.4), lineWidth: 1)
                    )
                }
                .disabled(musicService.isPerformingLibraryAction)
            }

            if savedToLibrary {
                Text("Playlist added to your Apple Music Library.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RetroTheme.amberGlow)
            }

            if let banner = musicService.statusBanner {
                Text(banner)
                    .font(.caption)
                    .foregroundStyle(RetroTheme.mutedCream)
            }

            LazyVStack(spacing: 8) {
                ForEach(Array(generatedTracks.enumerated()), id: \.element.id) { index, song in
                    Button {
                        playTrack(at: index)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(activeIndex == index ? RetroTheme.vegasGold : RetroTheme.mutedCream)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(activeIndex == index ? RetroTheme.vegasGold : RetroTheme.sunCream)
                                    .lineLimit(1)
                                Text("\(song.artist) • \(String(song.year))")
                                    .font(.caption)
                                    .foregroundStyle(RetroTheme.mutedCream)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: activeIndex == index && musicService.isPlayingPreview ? "speaker.wave.2.fill" : "play.circle")
                                .foregroundStyle(activeIndex == index ? RetroTheme.vegasGold : RetroTheme.mutedCream)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(activeIndex == index ? RetroTheme.elevatedSurface : RetroTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var placeholderArtwork: some View {
        ZStack {
            RetroTheme.elevatedSurface
            Image(systemName: "music.note")
                .foregroundStyle(RetroTheme.vegasGold)
        }
    }

    private var canGoPrevious: Bool {
        guard let activeIndex else { return false }
        return activeIndex > 0
    }

    private var canGoNext: Bool {
        guard let activeIndex else { return false }
        return activeIndex + 1 < generatedTracks.count
    }

    private func generatePlaylist() {
        let trimmed = feelingInput.trimmingCharacters(in: .whitespacesAndNewlines)
        var matches = database.matchingSongs(mood: nil, query: trimmed, artistFilter: .all)
        if matches.isEmpty {
            matches = database.songs
        }
        generatedTracks = Array(matches.shuffled().prefix(trackCount))
        activeIndex = generatedTracks.isEmpty ? nil : 0
        savedToLibrary = false
        playlistName = trimmed.isEmpty ? "Elvis Surprise Mix" : "Elvis: \(trimmed.capitalized)"
    }

    private func playTrack(at index: Int) {
        guard generatedTracks.indices.contains(index) else { return }
        activeIndex = index
        let song = generatedTracks[index]

        musicService.onTrackFinished = {
            playNextTrack()
        }

        playbackTask?.cancel()
        playbackTask = Task {
            await musicService.lookupCatalogSong(for: song)
            guard !Task.isCancelled else { return }
            _ = await musicService.play(record: song)
        }
    }

    private func playPreviousTrack() {
        guard let activeIndex, activeIndex > 0 else { return }
        playTrack(at: activeIndex - 1)
    }

    private func playNextTrack() {
        guard let activeIndex, activeIndex + 1 < generatedTracks.count else { return }
        playTrack(at: activeIndex + 1)
    }
}

#Preview {
    PlaylistGeneratorView(musicService: MusicKitService(), database: SongDatabase())
}
