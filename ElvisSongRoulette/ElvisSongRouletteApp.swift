import SwiftUI

@main
struct ElvisSongRouletteApp: App {
    @State private var musicService = MusicKitService()
    @State private var database = SongDatabase()
    @State private var ftdCatalog = FTDCatalog()
    @State private var playlistQueue: [SongRecord] = []

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView(musicService: musicService, database: database, playlistQueue: $playlistQueue)
                    .tabItem {
                        Label("Roulette", systemImage: "die.face.5.fill")
                    }

                PlaylistQueueView(queue: $playlistQueue, musicService: musicService, database: database, isPresentedAsSheet: false)
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }

                FTDView(catalog: ftdCatalog)
                    .tabItem {
                        Label("FTD Label", systemImage: "opticaldisc.fill")
                    }

                SettingsView(musicService: musicService, database: database, ftdCatalog: ftdCatalog)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .tint(RetroTheme.vegasGold)
            .task {
                async let songsUpdate = database.refreshFromRemote()
                async let ftdUpdate = ftdCatalog.refreshFromRemote()
                _ = await (songsUpdate, ftdUpdate)
            }
        }
    }
}
