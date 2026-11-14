import SwiftUI

@main
struct ElvisSongRouletteApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var musicService = MusicKitService()
    @State private var database = SongDatabase()
    @State private var ftdCatalog = FTDCatalog()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    TabView {
                        ContentView(musicService: musicService, database: database)
                            .tabItem {
                                Label("Roulette", systemImage: "die.face.5.fill")
                            }

                        PlaylistGeneratorView(musicService: musicService, database: database)
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
                } else {
                    OnboardingSplashView(musicService: musicService) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasCompletedOnboarding = true
                        }
                    }
                }
            }
            .task {
                async let songsUpdate = database.refreshFromRemote()
                async let ftdUpdate = ftdCatalog.refreshFromRemote()
                _ = await (songsUpdate, ftdUpdate)
            }
        }
    }
}
