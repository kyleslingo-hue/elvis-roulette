import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Standalone mood-to-playlist generator powered by Apple Foundation Models & direct Apple Music search.
struct PlaylistGeneratorView: View {
    let musicService: MusicKitService

    @State private var feelingInput = ""
    @State private var trackCount = 15
    @State private var generatedTracks: [AppleMusicPlaylistTrack] = []
    @State private var activeIndex: Int? = nil
    @State private var playlistName = "Elvis Mood Mix"
    @State private var curationSourceLabel = ""
    @State private var isGenerating = false
    @State private var savedToLibrary = false
    @State private var generationTask: Task<Void, Never>?
    @State private var playbackTask: Task<Void, Never>?

    private let quickFeelings = ["Missing someone", "Christmas", "Late Night", "Heartbroken", "High Energy", "Gospel", "Lisa Marie"]

    private var activeTrack: AppleMusicPlaylistTrack? {
        guard let activeIndex, generatedTracks.indices.contains(activeIndex) else { return nil }
        return generatedTracks[activeIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    feelingPromptCard

                    if let track = activeTrack {
                        nowPlayingCard(track)
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
                TextField("e.g. missing someone, christmas, late night, Vegas...", text: $feelingInput)
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
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(RetroTheme.vinylBlack)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(isGenerating ? "Building..." : "Generate")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RetroTheme.vegasGold)
                    .foregroundStyle(RetroTheme.vinylBlack)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(isGenerating)
            }

            Label(
                "Uses Apple Foundation Models on Apple Intelligence devices, with smart keyword & Apple Music catalog matching on all other devices.",
                systemImage: "apple.intelligence"
            )
            .font(.caption2)
            .foregroundStyle(RetroTheme.mutedCream)
        }
        .padding(16)
        .background(RetroTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RetroTheme.vegasGold.opacity(0.25), lineWidth: 1)
        )
    }

    private func nowPlayingCard(_ track: AppleMusicPlaylistTrack) -> some View {
        let isResolvedForTrack = musicService.resolvedRecordID == track.id
        let isPlayingThisTrack = isResolvedForTrack && musicService.isPlayingPreview

        return VStack(spacing: 14) {
            HStack(spacing: 14) {
                Group {
                    if let artURL = track.artworkURL ?? (isResolvedForTrack ? musicService.artworkURL : nil) {
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
                    Text(isPlayingThisTrack ? "NOW PLAYING" : "READY TO PLAY")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(RetroTheme.vegasGold)

                    Text(track.title)
                        .font(.headline)
                        .foregroundStyle(RetroTheme.sunCream)
                        .lineLimit(1)

                    Text("\(track.artistName) • \(track.albumTitle)")
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
                        .frame(width: proxy.size.width * (isResolvedForTrack ? musicService.previewProgress : 0), height: 5)
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
                    if isPlayingThisTrack {
                        playbackTask?.cancel()
                        musicService.stopPreview()
                    } else if let activeIndex {
                        playTrack(at: activeIndex)
                    }
                } label: {
                    Image(systemName: isPlayingThisTrack ? "pause.fill" : "play.fill")
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
                    Text(curationSourceLabel.isEmpty ? "\(generatedTracks.count) tracks from Apple Music" : "\(generatedTracks.count) tracks • \(curationSourceLabel)")
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
                            description: "Generated from feeling '\(feelingInput.isEmpty ? "Surprise Mix" : feelingInput)' via Elvis Song Roulette.",
                            tracks: generatedTracks
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
                ForEach(Array(generatedTracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        playTrack(at: index)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(activeIndex == index ? RetroTheme.vegasGold : RetroTheme.mutedCream)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(activeIndex == index ? RetroTheme.vegasGold : RetroTheme.sunCream)
                                    .lineLimit(1)
                                Text(track.releaseYear.map { "\(track.artistName) • \($0)" } ?? track.artistName)
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
        generationTask?.cancel()
        savedToLibrary = false
        isGenerating = true

        generationTask = Task {
            defer { isGenerating = false }

            let (title, queries, usedAI) = await buildSearchPlan(for: trimmed, count: trackCount)
            guard !Task.isCancelled else { return }

            let tracks = await musicService.searchAppleMusicTracks(queries: queries, targetCount: trackCount)
            guard !Task.isCancelled else { return }

            playlistName = title
            curationSourceLabel = usedAI ? "Apple Intelligence" : "Apple Music Smart Match"
            generatedTracks = tracks
            activeIndex = tracks.isEmpty ? nil : 0
        }
    }

    private func buildSearchPlan(for feeling: String, count: Int) async -> (String, [String], Bool) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.availability == .available {
            do {
                let session = LanguageModelSession(
                    instructions: "You are an Elvis Presley and Lisa Marie Presley music curator. Given how the user is feeling, provide a short playlist title and a list of specific Elvis Presley or Lisa Marie Presley song search queries (e.g. 'Always on My Mind Elvis Presley', 'Lights Out Lisa Marie Presley') that fit that mood."
                )
                let prompt = feeling.isEmpty
                    ? "Surprise me with \(count) diverse Elvis Presley and Lisa Marie Presley songs."
                    : "The user says they are feeling: \"\(feeling)\". Suggest \(count) Elvis Presley and/or Lisa Marie Presley song queries that match."
                let response = try await session.respond(to: prompt, generating: FoundationMoodPlan.self)
                let queries = response.content.songQueries.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                if !queries.isEmpty {
                    let title = response.content.playlistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    return (title.isEmpty ? "Elvis: \(feeling.capitalized)" : title, queries, true)
                }
            } catch {
                // Fall back to smart Apple Music search queries below
            }
        }
        #endif

        let (title, queries) = fallbackSearchPlan(for: feeling)
        return (title, queries, false)
    }

    private func fallbackSearchPlan(for feeling: String) -> (String, [String]) {
        let lower = feeling.lowercased()
        let title = feeling.isEmpty ? "Elvis Surprise Mix" : "Elvis: \(feeling.capitalized)"

        if lower.contains("miss") || lower.contains("lonely") || lower.contains("alone") || lower.contains("heartbreak") || lower.contains("heartbroken") || lower.contains("sad") {
            return (title, [
                "Always on My Mind Elvis Presley",
                "Separate Ways Elvis Presley",
                "Are You Lonesome Tonight Elvis Presley",
                "In the Ghetto Elvis Presley",
                "Kentucky Rain Elvis Presley",
                "Heartbreak Hotel Elvis Presley",
                "It's Over Elvis Presley",
                "Over Me Lisa Marie Presley",
                "Lights Out Lisa Marie Presley",
                "You Gave Me a Mountain Elvis Presley",
                "Don't Cry Daddy Elvis Presley",
                "Love Me Tender Elvis Presley",
                "I'll Be Home for Christmas Elvis Presley",
                "Unchained Melody Elvis Presley",
                "That's Someone You Never Forget Elvis Presley"
            ])
        } else if lower.contains("christmas") || lower.contains("holiday") || lower.contains("xmas") || lower.contains("winter") {
            return ("Elvis Christmas Mix", [
                "Blue Christmas Elvis Presley",
                "Santa Claus Is Back in Town Elvis Presley",
                "If Every Day Was Like Christmas Elvis Presley",
                "Here Comes Santa Claus Elvis Presley",
                "White Christmas Elvis Presley",
                "Silent Night Elvis Presley",
                "Winter Wonderland Elvis Presley",
                "Silver Bells Elvis Presley",
                "O Come All Ye Faithful Elvis Presley",
                "I'll Be Home for Christmas Elvis Presley",
                "Merry Christmas Baby Elvis Presley",
                "The Wonderful World of Christmas Elvis Presley"
            ])
        } else if lower.contains("lisa") {
            return ("Lisa Marie Presley Mix", [
                "Lights Out Lisa Marie Presley",
                "Dirty Laundry Lisa Marie Presley",
                "Idiot Lisa Marie Presley",
                "You Ain't Seen Nothin' Yet Lisa Marie Presley",
                "Over Me Lisa Marie Presley",
                "Storm & Grace Lisa Marie Presley",
                "Sinking In Lisa Marie Presley",
                "Shine Lisa Marie Presley",
                "Nobody Noticed It Lisa Marie Presley",
                "Weary Lisa Marie Presley",
                "Now What Lisa Marie Presley",
                "In the Ghetto Elvis Presley Lisa Marie"
            ])
        } else if lower.contains("gospel") || lower.contains("peace") || lower.contains("church") || lower.contains("pray") {
            return ("Elvis Gospel & Peace", [
                "How Great Thou Art Elvis Presley",
                "Crying in the Chapel Elvis Presley",
                "Peace in the Valley Elvis Presley",
                "Amazing Grace Elvis Presley",
                "He Touched Me Elvis Presley",
                "Swing Down Sweet Chariot Elvis Presley",
                "In the Garden Elvis Presley",
                "Take My Hand Precious Lord Elvis Presley",
                "You'll Never Walk Alone Elvis Presley",
                "If I Can Dream Elvis Presley"
            ])
        } else if lower.contains("energy") || lower.contains("party") || lower.contains("rock") || lower.contains("happy") || lower.contains("dance") || lower.contains("vegas") {
            return (title, [
                "Burning Love Elvis Presley",
                "Jailhouse Rock Elvis Presley",
                "Viva Las Vegas Elvis Presley",
                "A Little Less Conversation Elvis Presley",
                "Hound Dog Elvis Presley",
                "Blue Suede Shoes Elvis Presley",
                "Rubberneckin' Elvis Presley",
                "Suspicious Minds Elvis Presley",
                "Bossa Nova Baby Elvis Presley",
                "All Shook Up Elvis Presley",
                "Promised Land Elvis Presley",
                "Polk Salad Annie Elvis Presley"
            ])
        } else if lower.contains("night") || lower.contains("sultry") || lower.contains("chill") || lower.contains("love") {
            return (title, [
                "Fever Elvis Presley",
                "Can't Help Falling in Love Elvis Presley",
                "One Night Elvis Presley",
                "Love Me Tender Elvis Presley",
                "Steamroller Blues Elvis Presley",
                "Reconsider Baby Elvis Presley",
                "The Wonder of You Elvis Presley",
                "It's Now or Never Elvis Presley",
                "A Mess of Blues Elvis Presley",
                "And I Love You So Elvis Presley"
            ])
        } else if !feeling.isEmpty {
            return (title, [
                "\(feeling) Elvis Presley",
                "Elvis Presley \(feeling)",
                "\(feeling) Lisa Marie Presley",
                "Suspicious Minds Elvis Presley",
                "Burning Love Elvis Presley",
                "Can't Help Falling in Love Elvis Presley",
                "In the Ghetto Elvis Presley",
                "Always on My Mind Elvis Presley",
                "Jailhouse Rock Elvis Presley",
                "Lights Out Lisa Marie Presley",
                "Viva Las Vegas Elvis Presley",
                "If I Can Dream Elvis Presley"
            ])
        } else {
            return (title, [
                "Suspicious Minds Elvis Presley",
                "Can't Help Falling in Love Elvis Presley",
                "Burning Love Elvis Presley",
                "Jailhouse Rock Elvis Presley",
                "Always on My Mind Elvis Presley",
                "In the Ghetto Elvis Presley",
                "Lights Out Lisa Marie Presley",
                "Blue Christmas Elvis Presley",
                "Viva Las Vegas Elvis Presley",
                "How Great Thou Art Elvis Presley"
            ])
        }
    }

    private func playTrack(at index: Int) {
        guard generatedTracks.indices.contains(index) else { return }
        activeIndex = index
        let track = generatedTracks[index]

        musicService.onTrackFinished = {
            playNextTrack()
        }

        playbackTask?.cancel()
        playbackTask = Task {
            _ = await musicService.playCatalogTrack(track)
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

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct FoundationMoodPlan {
    @Guide(description: "A short, catchy playlist title matching the user's mood.")
    var playlistTitle: String

    @Guide(description: "Specific Elvis Presley and Lisa Marie Presley song search queries in 'Song Title Artist' format.")
    var songQueries: [String]
}
#endif

#Preview {
    PlaylistGeneratorView(musicService: MusicKitService())
}
