import MusicKit
import SwiftUI
import UIKit

/// App preferences, Apple Music connection status, and catalog/source details.
struct SettingsView: View {
    let musicService: MusicKitService
    let database: SongDatabase
    let ftdCatalog: FTDCatalog

    @AppStorage("autoPlayOnSpin") private var autoPlayOnSpin = false
    @AppStorage("includeUnavailableTracks") private var includeUnavailableTracks = true
    @AppStorage("defaultArtistFilter") private var defaultArtistFilterRaw = ArtistFilter.all.rawValue

    @State private var isCheckingUpdates = false
    @State private var updateMessage: String?

    var body: some View {
        ZStack {
            RetroTheme.vinylBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                HoundstoothAccentStrip(tileSize: 12)
                    .frame(height: 16)

                Form {
                    appleMusicSection
                    roulettePreferencesSection
                    catalogStatsSection
                    sourcesAndAboutSection
                }
                .scrollContentBackground(.hidden)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var appleMusicSection: some View {
        Section {
            HStack {
                Label("Authorization Status", systemImage: "music.note")
                    .foregroundStyle(RetroTheme.sunCream)
                Spacer()
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(musicService.isAuthorized ? RetroTheme.amberGlow : RetroTheme.mutedCream)
            }

            if !musicService.isAuthorized {
                Button {
                    if musicService.authorizationStatus == .denied {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } else {
                        Task { await musicService.requestAuthorization() }
                    }
                } label: {
                    Label(
                        musicService.authorizationStatus == .denied ? "Open iOS Settings" : "Connect Apple Music",
                        systemImage: "link.circle.fill"
                    )
                    .foregroundStyle(RetroTheme.vegasGold)
                    .fontWeight(.semibold)
                }
            }
        } header: {
            Text("Apple Music")
                .foregroundStyle(RetroTheme.vegasGold)
        }
        .listRowBackground(RetroTheme.cardSurface)
    }

    private var roulettePreferencesSection: some View {
        Section {
            Toggle(isOn: $autoPlayOnSpin) {
                Label("Auto-Play Audio on Spin", systemImage: "play.circle")
                    .foregroundStyle(RetroTheme.sunCream)
            }
            .tint(RetroTheme.vegasGold)

            Toggle(isOn: $includeUnavailableTracks) {
                Label("Include Non-Apple Music Tracks", systemImage: "music.quarternote.3")
                    .foregroundStyle(RetroTheme.sunCream)
            }
            .tint(RetroTheme.vegasGold)

            Picker(selection: $defaultArtistFilterRaw) {
                ForEach(ArtistFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter.rawValue)
                }
            } label: {
                Label("Default Artist Filter", systemImage: "person.2.fill")
                    .foregroundStyle(RetroTheme.sunCream)
            }
            .tint(RetroTheme.vegasGold)
        } header: {
            Text("Roulette & Playback")
                .foregroundStyle(RetroTheme.vegasGold)
        }
        .listRowBackground(RetroTheme.cardSurface)
    }

    private var catalogStatsSection: some View {
        Section {
            statRow("Total Roulette Tracks", value: "\(database.songs.count)")
            statRow("Elvis Presley Tracks", value: "\(database.songs.filter { $0.artist.contains("Elvis") }.count)")
            statRow("Lisa Marie Presley Tracks", value: "\(database.songs.filter { $0.isLisaMarie }.count)")
            statRow("FTD Collector Releases", value: "\(ftdCatalog.releases.count)")
            statRow("Catalog Source", value: database.lastUpdatedDescription)

            Button {
                Task {
                    isCheckingUpdates = true
                    async let songsOK = database.refreshFromRemote()
                    async let ftdOK = ftdCatalog.refreshFromRemote()
                    let (s, f) = await (songsOK, ftdOK)
                    isCheckingUpdates = false
                    updateMessage = (s || f) ? "Catalog synced from GitHub." : "Already up to date (or offline)."
                }
            } label: {
                HStack {
                    Label("Check for Catalog Updates", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(RetroTheme.vegasGold)
                        .fontWeight(.semibold)
                    Spacer()
                    if isCheckingUpdates {
                        ProgressView().tint(RetroTheme.vegasGold)
                    }
                }
            }
            .disabled(isCheckingUpdates)

            if let updateMessage {
                Text(updateMessage)
                    .font(.caption)
                    .foregroundStyle(RetroTheme.amberGlow)
            }
        } header: {
            Text("Catalog")
                .foregroundStyle(RetroTheme.vegasGold)
        }
        .listRowBackground(RetroTheme.cardSurface)
    }

    private var sourcesAndAboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Session & Discography Sources")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RetroTheme.sunCream)
                Text("Ernst Jorgensen’s 'Elvis Presley: A Life in Music', Elvis.com, ElvisOnCD.com (Follow That Dream), and Apple Music / MusicKit.")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.mutedCream)
            }
            .padding(.vertical, 4)

            statRow("App Version", value: appVersion)
        } header: {
            Text("About")
                .foregroundStyle(RetroTheme.vegasGold)
        }
        .listRowBackground(RetroTheme.cardSurface)
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(RetroTheme.sunCream)
            Spacer()
            Text(value)
                .foregroundStyle(RetroTheme.mutedCream)
                .fontWeight(.medium)
        }
    }

    private var statusText: String {
        switch musicService.authorizationStatus {
        case .authorized: return "Connected"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Connected"
        @unknown default: return "Unknown"
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

#Preview {
    SettingsView(musicService: MusicKitService(), database: SongDatabase(), ftdCatalog: FTDCatalog())
}
