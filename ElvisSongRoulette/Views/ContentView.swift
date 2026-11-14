import SwiftUI

struct ContentView: View {
    var musicService: MusicKitService
    var database: SongDatabase

    @AppStorage("autoPlayOnSpin") private var autoPlayOnSpin = true
    @AppStorage("includeUnavailableTracks") private var includeUnavailableTracks = true
    @AppStorage("defaultArtistFilter") private var defaultArtistFilterRaw = ArtistFilter.all.rawValue

    @State private var selectedMood: Mood? = nil
    @State private var artistFilter: ArtistFilter = .all
    @State private var currentSong: SongRecord?
    @State private var playlistQueue: [SongRecord] = []
    @State private var isAutoplaySessionActive = false
    @State private var spinTask: Task<Void, Never>?

    @State private var showingSessionHistory = false
    @State private var showingPlaylistBuilder = false

    var body: some View {
        ZStack {
            RetroTheme.vinylBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                HoundstoothAccentStrip(tileSize: 12)
                    .frame(height: 16)

                ScrollView {
                    VStack(spacing: 18) {
                        headerBar
                        moodSelectorSection
                        if let song = currentSong {
                            featuredSongCard(song)
                        }
                        if let banner = musicService.statusBanner {
                            statusToast(banner)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }

            VStack {
                Spacer()
                spinButtonBar
            }
        }
        .preferredColorScheme(.dark)
        .task {
            musicService.onTrackFinished = {
                if isAutoplaySessionActive && autoPlayOnSpin {
                    spinTrack(startAutoplay: true)
                }
            }
            if currentSong == nil {
                if let saved = ArtistFilter(rawValue: defaultArtistFilterRaw) {
                    artistFilter = saved
                }
                spinTrack(startAutoplay: false)
            }
        }
        .sheet(isPresented: $showingSessionHistory) {
            if let currentSong {
                SessionHistoryView(song: currentSong, appleMusicMetadata: musicService.resolvedMetadata)
            }
        }
        .sheet(isPresented: $showingPlaylistBuilder) {
            PlaylistQueueView(queue: $playlistQueue, musicService: musicService)
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ELVIS & LISA MARIE")
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(RetroTheme.vegasGold)
                Text("Song Roulette")
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(RetroTheme.sunCream)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    Task { await musicService.requestAuthorization() }
                } label: {
                    Image(systemName: musicService.isAuthorized ? "checkmark.circle.fill" : "music.note")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(musicService.isAuthorized ? RetroTheme.amberGlow : RetroTheme.sunCream)
                        .padding(10)
                        .background(RetroTheme.cardSurface)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(RetroTheme.vegasGold.opacity(0.4), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Connect Apple Music")

                Button {
                    showingPlaylistBuilder = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("\(playlistQueue.count)")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(RetroTheme.vinylBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RetroTheme.vegasGold)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("Open Playlist Queue")
            }
        }
    }

    private var moodSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mood pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    moodPill(title: "All Moods", icon: "shuffle", isSelected: selectedMood == nil) {
                        selectedMood = nil
                        spinTrack()
                    }
                    ForEach(Mood.allCases) { mood in
                        moodPill(
                            title: mood.displayName,
                            icon: mood.systemImage,
                            isSelected: selectedMood == mood
                        ) {
                            selectedMood = mood
                            spinTrack()
                        }
                    }
                }
            }

            // Artist filter
            Picker("Artist", selection: $artistFilter) {
                ForEach(ArtistFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: artistFilter) { _, _ in
                spinTrack()
            }
        }
    }

    private func moodPill(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? RetroTheme.vegasGold : RetroTheme.cardSurface)
            .foregroundStyle(isSelected ? RetroTheme.vinylBlack : RetroTheme.sunCream)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(RetroTheme.vegasGold.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
            )
        }
    }

    private func featuredSongCard(_ song: SongRecord) -> some View {
        VStack(spacing: 16) {
            GoldVinylArtworkView(
                artworkURL: musicService.artworkURL,
                title: song.title,
                artist: song.artist,
                isSpinning: musicService.isPlayingPreview
            )
            .padding(.top, 6)

            VStack(spacing: 6) {
                Text(song.artist.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(song.isLisaMarie ? RetroTheme.amberGlow : RetroTheme.vegasGold)

                Text(song.title)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(RetroTheme.sunCream)
                    .multilineTextAlignment(.center)

                Text("\(musicService.resolvedAlbumTitle ?? song.album) • \(String(song.year))")
                    .font(.subheadline)
                    .foregroundStyle(RetroTheme.mutedCream)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Text(song.era)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RetroTheme.vegasGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RetroTheme.vegasGold.opacity(0.14))
                        .clipShape(Capsule())

                    if !song.isOnAppleMusic {
                        Text("Not on Apple Music")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RetroTheme.sunCream)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(RetroTheme.memphisCrimson.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }
            }

            // 30-Second Preview Bar
            previewBar(song)

            // Quick Session Snippet
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(RetroTheme.vegasGold)
                Text("\(song.session.date) — \(song.session.location)")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.mutedCream)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RetroTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Actionable UI Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                actionButton(
                    title: "History & Sessions",
                    icon: "book.closed.fill",
                    highlighted: true
                ) {
                    showingSessionHistory = true
                }

                actionButton(
                    title: isQueued(song) ? "Queued" : "Queue for Mix",
                    icon: isQueued(song) ? "checkmark" : "text.badge.plus"
                ) {
                    toggleQueue(song)
                }

                actionButton(
                    title: "Add to Library",
                    icon: "plus.circle.fill"
                ) {
                    Task { await musicService.addToLibrary(record: song) }
                }

                actionButton(
                    title: "Apple Music",
                    icon: "arrow.up.right.square.fill"
                ) {
                    musicService.openInAppleMusic(record: song)
                }
            }
        }
        .padding(18)
        .background(RetroTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RetroTheme.vegasGold.opacity(0.35), lineWidth: 1.2)
        )
    }

    private func previewBar(_ song: SongRecord) -> some View {
        HStack(spacing: 12) {
            Button {
                if musicService.isPlayingPreview {
                    isAutoplaySessionActive = false
                    spinTask?.cancel()
                    musicService.stopPreview()
                } else {
                    isAutoplaySessionActive = autoPlayOnSpin
                    musicService.togglePreview(for: song)
                }
            } label: {
                Image(systemName: musicService.isPlayingPreview ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .foregroundStyle(RetroTheme.vinylBlack)
                    .frame(width: 38, height: 38)
                    .background(RetroTheme.vegasGold)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(musicService.isPlayingPreview ? "Playing Elvis Music" : "Play Elvis Music")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RetroTheme.sunCream)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(RetroTheme.vegasGold)
                        .frame(width: 16, height: 16)
                        .opacity(musicService.isLookingUp ? 1 : 0)
                }
                .frame(height: 18)

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
            }
        }
        .padding(12)
        .background(RetroTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func actionButton(
        title: String,
        icon: String,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .padding(.horizontal, 8)
            .background(highlighted ? RetroTheme.vegasGold.opacity(0.18) : RetroTheme.elevatedSurface)
            .foregroundStyle(highlighted ? RetroTheme.amberGlow : RetroTheme.sunCream)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RetroTheme.vegasGold.opacity(highlighted ? 0.5 : 0.15), lineWidth: 1)
            )
        }
    }

    private var spinButtonBar: some View {
        VStack(spacing: 0) {
            Button {
                spinTrack()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "die.face.5.fill")
                        .font(.title3)
                    Text("SPIN ROULETTE")
                        .font(.headline.weight(.heavy))
                        .tracking(1.1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [RetroTheme.amberGlow, RetroTheme.vegasGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(RetroTheme.vinylBlack)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: RetroTheme.vegasGold.opacity(0.35), radius: 12, y: 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [RetroTheme.vinylBlack.opacity(0), RetroTheme.vinylBlack.opacity(0.95), RetroTheme.vinylBlack],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func statusToast(_ message: String) -> some View {
        Text(message)
            .font(.caption.weight(.medium))
            .foregroundStyle(RetroTheme.sunCream)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RetroTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func spinTrack(startAutoplay: Bool = true) {
        isAutoplaySessionActive = startAutoplay && autoPlayOnSpin
        musicService.onTrackFinished = {
            if isAutoplaySessionActive && autoPlayOnSpin {
                spinTrack(startAutoplay: true)
            }
        }
        spinTask?.cancel()

        guard let next = database.spin(
            mood: selectedMood,
            query: "",
            artistFilter: artistFilter,
            excludingID: currentSong?.id
        ) else {
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentSong = next
        }
        spinTask = Task {
            await musicService.lookupCatalogSong(for: next)
            guard !Task.isCancelled else { return }
            if startAutoplay && autoPlayOnSpin {
                let started = await musicService.play(record: next)
                if !started {
                    isAutoplaySessionActive = false
                }
            }
        }
    }

    private func isQueued(_ song: SongRecord) -> Bool {
        playlistQueue.contains(where: { $0.id == song.id })
    }

    private func toggleQueue(_ song: SongRecord) {
        if let index = playlistQueue.firstIndex(where: { $0.id == song.id }) {
            playlistQueue.remove(at: index)
        } else {
            playlistQueue.append(song)
        }
    }
}

#Preview {
    ContentView(musicService: MusicKitService(), database: SongDatabase())
}
