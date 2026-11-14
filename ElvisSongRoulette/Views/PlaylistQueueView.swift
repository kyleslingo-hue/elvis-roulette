import SwiftUI

/// Compiles custom mood/search mixes and queued Roulette spins into an Apple Music playlist.
struct PlaylistQueueView: View {
    @Binding var queue: [SongRecord]
    let musicService: MusicKitService
    var database: SongDatabase = SongDatabase()
    var isPresentedAsSheet: Bool = true
    @Environment(\.dismiss) private var dismiss

    @State private var searchPrompt = ""
    @State private var selectedMood: Mood? = nil
    @State private var artistFilter: ArtistFilter = .all
    @State private var trackCount = 15

    @State private var playlistName = "Elvis Roulette Mix"
    @State private var playlistDescription = "Curated mood spins from Elvis Presley & Lisa Marie Presley via Elvis Song Roulette."
    @State private var createdSuccessfully = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    generatorSection

                    if queue.isEmpty {
                        Section {
                            VStack(spacing: 8) {
                                Image(systemName: "music.note.list")
                                    .font(.title2)
                                    .foregroundStyle(RetroTheme.vegasGold)
                                Text("No Tracks in Mix Yet")
                                    .font(.headline)
                                    .foregroundStyle(RetroTheme.sunCream)
                                Text("Use Build Mix above or tap Queue for Mix on the Roulette tab.")
                                    .font(.caption)
                                    .foregroundStyle(RetroTheme.mutedCream)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                        .listRowBackground(RetroTheme.cardSurface)
                    } else {
                        Section {
                            TextField("Playlist Name", text: $playlistName)
                                .foregroundStyle(RetroTheme.sunCream)
                            TextField("Description", text: $playlistDescription, axis: .vertical)
                                .lineLimit(2...4)
                                .foregroundStyle(RetroTheme.mutedCream)
                        } header: {
                            Text("Playlist Details")
                                .foregroundStyle(RetroTheme.vegasGold)
                        }
                        .listRowBackground(RetroTheme.cardSurface)

                        Section {
                            ForEach(queue) { song in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(song.title)
                                            .font(.headline)
                                            .foregroundStyle(RetroTheme.sunCream)
                                        Text("\(song.artist) • \(String(song.year))")
                                            .font(.caption)
                                            .foregroundStyle(RetroTheme.mutedCream)
                                    }
                                    Spacer()
                                    Text(song.era)
                                        .font(.caption2)
                                        .foregroundStyle(RetroTheme.vegasGold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(RetroTheme.vegasGold.opacity(0.14))
                                        .clipShape(Capsule())
                                }
                            }
                            .onDelete { offsets in
                                queue.remove(atOffsets: offsets)
                            }
                        } header: {
                            Text("Queued Tracks (\(queue.count))")
                                .foregroundStyle(RetroTheme.vegasGold)
                        }
                        .listRowBackground(RetroTheme.cardSurface)
                    }
                }
                .scrollContentBackground(.hidden)

                if !queue.isEmpty {
                    VStack(spacing: 10) {
                        Button {
                            Task {
                                let success = await musicService.createPlaylist(
                                    name: playlistName,
                                    description: playlistDescription,
                                    records: queue
                                )
                                createdSuccessfully = success
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if musicService.isPerformingLibraryAction {
                                    ProgressView()
                                        .tint(RetroTheme.vinylBlack)
                                } else {
                                    Image(systemName: "plus.square.on.square")
                                }
                                Text("Generate Apple Music Playlist")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RetroTheme.vegasGold)
                            .foregroundStyle(RetroTheme.vinylBlack)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(musicService.isPerformingLibraryAction)

                        if createdSuccessfully {
                            Text("Playlist saved to your Apple Music Library.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RetroTheme.amberGlow)
                        }
                    }
                    .padding()
                    .background(RetroTheme.cardSurface)
                }
            }
            .background(RetroTheme.vinylBlack.ignoresSafeArea())
            .navigationTitle("Playlist Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !queue.isEmpty {
                        Button("Clear") {
                            queue.removeAll()
                            createdSuccessfully = false
                        }
                        .foregroundStyle(RetroTheme.memphisCrimson)
                    }
                }
                if isPresentedAsSheet {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(RetroTheme.vegasGold)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var generatorSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(RetroTheme.vegasGold)
                TextField("Theme or mood (e.g. christmas, late night, Vegas)...", text: $searchPrompt)
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.sunCream)
                if !searchPrompt.isEmpty {
                    Button {
                        searchPrompt = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(RetroTheme.mutedCream)
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("Mood", selection: $selectedMood) {
                Text("All Moods").tag(Optional<Mood>.none)
                ForEach(Mood.allCases) { mood in
                    Text(mood.displayName).tag(Optional(mood))
                }
            }
            .foregroundStyle(RetroTheme.sunCream)
            .tint(RetroTheme.vegasGold)

            Picker("Artist", selection: $artistFilter) {
                ForEach(ArtistFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .foregroundStyle(RetroTheme.sunCream)
            .tint(RetroTheme.vegasGold)

            Picker("Tracks", selection: $trackCount) {
                Text("10 Songs").tag(10)
                Text("15 Songs").tag(15)
                Text("25 Songs").tag(25)
                Text("50 Songs").tag(50)
            }
            .foregroundStyle(RetroTheme.sunCream)
            .tint(RetroTheme.vegasGold)

            Button {
                buildMix()
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Build Mix")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(RetroTheme.vegasGold)
            }
        } header: {
            Text("Generate Mix")
                .foregroundStyle(RetroTheme.vegasGold)
        }
        .listRowBackground(RetroTheme.cardSurface)
    }

    private func buildMix() {
        var matches = database.matchingSongs(
            mood: selectedMood,
            query: searchPrompt,
            artistFilter: artistFilter
        )
        if matches.isEmpty {
            matches = database.matchingSongs(mood: selectedMood, query: "", artistFilter: artistFilter)
        }
        let picked = Array(matches.shuffled().prefix(trackCount))
        queue = picked
        createdSuccessfully = false

        let trimmed = searchPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            playlistName = "Elvis Mix: \(trimmed.capitalized)"
        } else if let selectedMood {
            playlistName = "Elvis \(selectedMood.displayName) Mix"
        } else {
            playlistName = "Elvis Roulette Mix"
        }
    }
}
