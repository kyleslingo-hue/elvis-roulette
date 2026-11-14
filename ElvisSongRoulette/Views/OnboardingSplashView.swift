import SwiftUI

/// First-launch welcome & how-to-use splash screen that requests Apple Music access on Get Started.
struct OnboardingSplashView: View {
    let musicService: MusicKitService
    let onComplete: () -> Void

    @State private var isRequestingPermission = false

    var body: some View {
        ZStack {
            RetroTheme.vinylBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                HoundstoothAccentStrip(tileSize: 12)

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        howToUseSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 20)
                }

                getStartedFooter
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(RetroTheme.vegasGold.opacity(0.14))
                    .frame(width: 78, height: 78)
                Image(systemName: "die.face.5.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(RetroTheme.vegasGold)
            }

            Text("ELVIS & LISA MARIE")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(RetroTheme.vegasGold)

            Text("Song Roulette")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(RetroTheme.sunCream)

            Text("Spin through 1,300+ Elvis & Lisa Marie Presley tracks, recording sessions, and collector releases.")
                .font(.subheadline)
                .foregroundStyle(RetroTheme.mutedCream)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var howToUseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HOW TO USE")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(RetroTheme.vegasGold)
                .padding(.leading, 4)

            stepCard(
                icon: "sparkles",
                title: "1. Pick a Mood & Spin",
                detail: "Select any mood pill — from Melancholy and High Energy to Christmas or Lisa — then tap Spin Roulette to play continuously until you stop."
            )

            stepCard(
                icon: "book.pages.fill",
                title: "2. Explore History & Sessions",
                detail: "Tap History & Sessions on any track to view studio dates, session musicians, backstories, and synced Apple Music release notes."
            )

            stepCard(
                icon: "music.note.list",
                title: "3. Generate Mood Playlists",
                detail: "Open the Playlists tab, type how you're feeling, listen with the built-in player, or save the mix directly to your Apple Music Library."
            )

            stepCard(
                icon: "opticaldisc.fill",
                title: "4. Browse FTD Collector Releases",
                detail: "Check the FTD Label tab to explore Follow That Dream collector editions and tracklists."
            )
        }
    }

    private func stepCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(RetroTheme.vegasGold)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RetroTheme.sunCream)
                Text(detail)
                    .font(.caption)
                    .lineSpacing(3)
                    .foregroundStyle(RetroTheme.mutedCream)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RetroTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RetroTheme.vegasGold.opacity(0.22), lineWidth: 1)
        )
    }

    private var getStartedFooter: some View {
        VStack(spacing: 10) {
            Button {
                guard !isRequestingPermission else { return }
                isRequestingPermission = true
                Task {
                    await musicService.requestAuthorization()
                    isRequestingPermission = false
                    onComplete()
                }
            } label: {
                HStack(spacing: 10) {
                    if isRequestingPermission {
                        ProgressView()
                            .tint(RetroTheme.vinylBlack)
                    } else {
                        Image(systemName: "music.note")
                    }
                    Text(isRequestingPermission ? "Connecting to Apple Music..." : "Get Started")
                        .font(.headline.weight(.heavy))
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
            .disabled(isRequestingPermission)

            Text("We'll ask for Apple Music access so you can play full tracks and save playlists.")
                .font(.caption2)
                .foregroundStyle(RetroTheme.mutedCream)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(RetroTheme.vinylBlack)
    }
}

#Preview {
    OnboardingSplashView(musicService: MusicKitService(), onComplete: {})
}
