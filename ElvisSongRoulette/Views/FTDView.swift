import SwiftUI

/// Dedicated page for Elvis Presley's Follow That Dream (FTD) collector label releases,
/// which are not available on Apple Music.
struct FTDView: View {
    var catalog: FTDCatalog

    @State private var searchQuery = ""
    @State private var selectedSeries: String?
    @State private var spotlightRelease: FTDRelease?

    private var filteredReleases: [FTDRelease] {
        catalog.filtered(query: searchQuery, series: selectedSeries)
    }

    var body: some View {
        ZStack {
            RetroTheme.vinylBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                HoundstoothAccentStrip(tileSize: 12)
                    .frame(height: 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        searchAndFilterSection

                        if let spotlight = spotlightRelease {
                            spotlightCard(spotlight)
                        }

                        Text("ALL RELEASES (\(filteredReleases.count))")
                            .font(.caption.weight(.bold))
                            .tracking(1.3)
                            .foregroundStyle(RetroTheme.vegasGold)
                            .padding(.top, 4)

                        LazyVStack(spacing: 12) {
                            ForEach(filteredReleases) { release in
                                releaseRow(release)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FOLLOW THAT DREAM")
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(RetroTheme.vegasGold)
                Text("FTD Collector Label")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(RetroTheme.sunCream)
                Text("Official collector CDs & books • Not on Apple Music")
                    .font(.caption)
                    .foregroundStyle(RetroTheme.mutedCream)
            }

            Spacer()

            Button {
                if let random = filteredReleases.randomElement() ?? catalog.releases.randomElement() {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        spotlightRelease = random
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "die.face.5.fill")
                    Text("Spin FTD")
                        .fontWeight(.bold)
                }
                .font(.caption)
                .foregroundStyle(RetroTheme.vinylBlack)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RetroTheme.vegasGold)
                .clipShape(Capsule())
            }
        }
    }

    private var searchAndFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(RetroTheme.vegasGold)
                TextField("Search FTD title, #001–#232, or year...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundStyle(RetroTheme.sunCream)

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(RetroTheme.mutedCream)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RetroTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RetroTheme.vegasGold.opacity(0.3), lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    seriesPill(title: "All Series", isSelected: selectedSeries == nil) {
                        selectedSeries = nil
                    }
                    ForEach(catalog.availableSeries, id: \.self) { series in
                        seriesPill(title: series, isSelected: selectedSeries == series) {
                            selectedSeries = series
                        }
                    }
                }
            }
        }
    }

    private func seriesPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? RetroTheme.vegasGold : RetroTheme.cardSurface)
                .foregroundStyle(isSelected ? RetroTheme.vinylBlack : RetroTheme.sunCream)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(RetroTheme.vegasGold.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
                )
        }
    }

    private func spotlightCard(_ release: FTDRelease) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FTD ROULETTE PICK • \(release.catalogNumber)")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(RetroTheme.amberGlow)
                Spacer()
                Button {
                    spotlightRelease = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(RetroTheme.mutedCream)
                }
            }

            releaseContent(release)
        }
        .padding(14)
        .background(RetroTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RetroTheme.vegasGold, lineWidth: 1.5)
        )
    }

    private func releaseRow(_ release: FTDRelease) -> some View {
        releaseContent(release)
            .padding(12)
            .background(RetroTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(RetroTheme.vegasGold.opacity(0.22), lineWidth: 1)
            )
    }

    private func releaseContent(_ release: FTDRelease) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: release.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    ZStack {
                        RetroTheme.elevatedSurface
                        Image(systemName: "opticaldisc")
                            .font(.title2)
                            .foregroundStyle(RetroTheme.vegasGold)
                    }
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(RetroTheme.vegasGold.opacity(0.45), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(release.catalogNumber)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(RetroTheme.vinylBlack)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RetroTheme.vegasGold)
                        .clipShape(Capsule())

                    Text(release.releaseDate)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RetroTheme.mutedCream)
                }

                Text(release.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RetroTheme.sunCream)
                    .lineLimit(2)

                Text("\(release.releaseType.capitalized) • \(release.series)")
                    .font(.caption2)
                    .foregroundStyle(RetroTheme.mutedCream)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if let infoURL = release.infoURL {
                Link(destination: infoURL) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.subheadline)
                        .foregroundStyle(RetroTheme.vegasGold)
                        .padding(6)
                }
                .accessibilityLabel("View \(release.title) on ElvisOnCD")
            }
        }
    }
}

#Preview {
    FTDView(catalog: FTDCatalog())
}
