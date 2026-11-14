import SwiftUI

/// Displays deep recording session data, personnel credits, and historical context
/// derived from the bundled session ledger database and enriched with live Apple Music metadata.
struct SessionHistoryView: View {
    let song: SongRecord
    var appleMusicMetadata: AppleMusicMetadata? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    recordingDetailsCard
                    if appleMusicMetadata != nil {
                        appleMusicCatalogCard
                    }
                    personnelCard
                    backstoryCard
                }
                .padding()
            }
            .background(RetroTheme.vinylBlack.ignoresSafeArea())
            .navigationTitle("History & Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(RetroTheme.vegasGold)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(song.era.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(RetroTheme.vegasGold)
                Spacer()
                if appleMusicMetadata != nil {
                    Label("Apple Music", systemImage: "music.note")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RetroTheme.vegasGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RetroTheme.vegasGold.opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            Text(appleMusicMetadata?.title ?? song.title)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(RetroTheme.sunCream)

            let displayArtist = appleMusicMetadata?.artistName ?? song.artist
            let displayAlbum = appleMusicMetadata?.albumTitle ?? song.album
            let displayYear = appleMusicMetadata?.releaseYear ?? song.year
            Text("\(displayArtist) • \(displayAlbum) (\(String(displayYear)))")
                .font(.subheadline)
                .foregroundStyle(RetroTheme.mutedCream)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RetroTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RetroTheme.vegasGold.opacity(0.35), lineWidth: 1)
        )
    }

    private var recordingDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Session Ledger", icon: "calendar.badge.clock")

            detailRow(label: "Recording Date", value: song.session.date, icon: "calendar")
            detailRow(label: "Studio / Location", value: song.session.location, icon: "mappin.and.ellipse")
            detailRow(label: "Producer", value: song.session.producer, icon: "slider.horizontal.3")
            detailRow(label: "Chart & Milestone", value: song.session.chartPeak, icon: "chart.line.uptrend.xyaxis")
        }
        .padding(16)
        .background(RetroTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var appleMusicCatalogCard: some View {
        if let meta = appleMusicMetadata {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Apple Music Release Data", icon: "music.note.list")

                if let album = meta.albumTitle, !album.isEmpty {
                    detailRow(label: "Release / Album", value: album, icon: "opticaldisc")
                }
                if let releaseDate = meta.formattedReleaseDate {
                    detailRow(label: "Release Date", value: releaseDate, icon: "calendar")
                }
                if let composer = meta.composerName, !composer.isEmpty {
                    detailRow(label: "Songwriters / Composer", value: composer, icon: "pencil.and.outline")
                }
                if !meta.genres.isEmpty {
                    detailRow(label: "Genre", value: meta.genres.joined(separator: ", "), icon: "tag")
                }
                if let duration = meta.formattedDuration {
                    detailRow(label: "Duration", value: duration, icon: "clock")
                }
                if let trackPos = meta.trackPositionLabel {
                    detailRow(label: "Album Position", value: trackPos, icon: "number")
                }
                if let isrc = meta.isrc, !isrc.isEmpty {
                    detailRow(label: "ISRC", value: isrc, icon: "barcode")
                }
            }
            .padding(16)
            .background(RetroTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var personnelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Session Personnel", icon: "guitars.fill")

            ForEach(song.session.musicians) { credit in
                HStack(alignment: .top) {
                    Text(credit.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RetroTheme.sunCream)
                    Spacer()
                    Text(credit.role)
                        .font(.caption)
                        .foregroundStyle(RetroTheme.mutedCream)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 2)
                Divider()
                    .background(Color.white.opacity(0.08))
            }

            if !song.session.backingVocals.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Backing Vocals")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RetroTheme.vegasGold)
                    Text(song.session.backingVocals.joined(separator: " • "))
                        .font(.subheadline)
                        .foregroundStyle(RetroTheme.sunCream)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(RetroTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var backstoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("The Backstory", icon: "book.pages.fill")

            Text(song.session.backstory)
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(RetroTheme.sunCream.opacity(0.92))

            if let editorial = appleMusicMetadata?.editorialNotes, !editorial.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 4)

                Text("APPLE MUSIC NOTES")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(RetroTheme.vegasGold)

                Text(editorial)
                    .font(.subheadline)
                    .lineSpacing(4)
                    .foregroundStyle(RetroTheme.mutedCream)
            }
        }
        .padding(16)
        .background(RetroTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(RetroTheme.vegasGold)
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(RetroTheme.vegasGold)
        }
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(RetroTheme.vegasGold.opacity(0.85))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(RetroTheme.mutedCream)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RetroTheme.sunCream)
            }
        }
    }
}
