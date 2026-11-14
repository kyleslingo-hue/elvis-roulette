import SwiftUI

enum RetroTheme {
    static let vinylBlack = Color(red: 0.067, green: 0.063, blue: 0.075)
    static let cardSurface = Color(red: 0.114, green: 0.106, blue: 0.125)
    static let elevatedSurface = Color(red: 0.165, green: 0.153, blue: 0.180)
    static let vegasGold = Color(red: 0.831, green: 0.686, blue: 0.216)
    static let amberGlow = Color(red: 0.953, green: 0.808, blue: 0.388)
    static let sunCream = Color(red: 0.969, green: 0.945, blue: 0.890)
    static let mutedCream = Color(red: 0.780, green: 0.745, blue: 0.675)
    static let memphisCrimson = Color(red: 0.620, green: 0.165, blue: 0.169)
}

/// Subtle houndstooth pattern accent inspired by mid-century Memphis tailoring.
struct HoundstoothAccentStrip: View {
    var tileSize: CGFloat = 14
    var foreground: Color = RetroTheme.vegasGold.opacity(0.22)
    var background: Color = RetroTheme.vinylBlack

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))
            let cols = Int(ceil(size.width / tileSize)) + 1
            let rows = Int(ceil(size.height / tileSize)) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * tileSize
                    let y = CGFloat(row) * tileSize
                    let half = tileSize / 2
                    let isEven = (row + col).isMultiple(of: 2)

                    var path = Path()
                    if isEven {
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + tileSize, y: y))
                        path.addLine(to: CGPoint(x: x + half, y: y + half))
                        path.addLine(to: CGPoint(x: x + tileSize, y: y + tileSize))
                        path.addLine(to: CGPoint(x: x, y: y + tileSize))
                        path.addLine(to: CGPoint(x: x + half, y: y + half))
                        path.closeSubpath()
                    } else {
                        path.move(to: CGPoint(x: x, y: y + half))
                        path.addLine(to: CGPoint(x: x + half, y: y))
                        path.addLine(to: CGPoint(x: x + half, y: y + half))
                        path.closeSubpath()
                    }
                    context.fill(path, with: .color(foreground))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Gold-label vinyl disc that pairs with album artwork or serves as a retro sleeve fallback.
struct GoldVinylArtworkView: View {
    let artworkURL: URL?
    let title: String
    let artist: String
    let isSpinning: Bool

    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Vinyl disc peeking out to the right
            vinylDisc
                .offset(x: 42)
                .rotationEffect(.degrees(rotationAngle))

            // Album sleeve on the left
            albumSleeve
                .offset(x: -22)
        }
        .frame(height: 184)
        .onChange(of: isSpinning) { _, spinning in
            if spinning {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotationAngle += 360
                }
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    rotationAngle = rotationAngle.truncatingRemainder(dividingBy: 360)
                }
            }
        }
    }

    private var vinylDisc: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.16),
                            Color(white: 0.05),
                            Color(white: 0.14),
                            Color(white: 0.04)
                        ],
                        center: .center,
                        startRadius: 16,
                        endRadius: 84
                    )
                )
                .frame(width: 164, height: 164)
                .overlay(
                    Circle()
                        .stroke(RetroTheme.vegasGold.opacity(0.45), lineWidth: 1.5)
                )

            // Grooves
            ForEach([44.0, 56.0, 68.0], id: \.self) { radius in
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                    .frame(width: radius * 2, height: radius * 2)
            }

            // Gold center label
            Circle()
                .fill(
                    LinearGradient(
                        colors: [RetroTheme.amberGlow, RetroTheme.vegasGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)

            Circle()
                .fill(RetroTheme.vinylBlack)
                .frame(width: 10, height: 10)
        }
        .shadow(color: .black.opacity(0.55), radius: 10, x: 4, y: 6)
    }

    private var albumSleeve: some View {
        Group {
            if let artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackSleeve
                    }
                }
            } else {
                fallbackSleeve
            }
        }
        .frame(width: 168, height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RetroTheme.vegasGold.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 8)
    }

    private var fallbackSleeve: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    RetroTheme.elevatedSurface,
                    RetroTheme.vinylBlack
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HoundstoothAccentStrip(
                tileSize: 12,
                foreground: RetroTheme.vegasGold.opacity(0.14),
                background: .clear
            )

            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundStyle(RetroTheme.vegasGold)
                Spacer()
                Text(artist.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.vegasGold)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(RetroTheme.sunCream)
                    .lineLimit(2)
            }
            .padding(12)
        }
    }
}
