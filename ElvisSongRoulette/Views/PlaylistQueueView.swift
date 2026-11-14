import SwiftUI

/// Compiles the rolling queue of spun songs into a brand-new Apple Music playlist.
struct PlaylistQueueView: View {
    @Binding var queue: [SongRecord]
    let musicService: MusicKitService
    @Environment(\.dismiss) private var dismiss

    @State private var playlistName = "Elvis Roulette Mix"
    @State private var playlistDescription = "Curated mood spins from Elvis Presley & Lisa Marie Presley via Elvis Song Roulette."
    @State private var createdSuccessfully = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if queue.isEmpty {
                    ContentUnavailableView(
                        "Your Roulette Queue Is Empty",
                        systemImage: "music.note.list",
                        description: Text("Spin tracks on the main screen and tap Queue to build a custom Apple Music playlist.")
                    )
                    .foregroundStyle(RetroTheme.sunCream)
                } else {
                    List {
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
                    .scrollContentBackground(.hidden)

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
            .navigationTitle("Playlist Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !queue.isEmpty {
                        Button("Clear") {
                            queue.removeAll()
                        }
                        .foregroundStyle(RetroTheme.memphisCrimson)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(RetroTheme.vegasGold)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
