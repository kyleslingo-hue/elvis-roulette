import Foundation

/// Emotional states supported by the Mood-to-Track selector and matching engine.
enum Mood: String, CaseIterable, Codable, Identifiable, Hashable {
    case melancholy
    case highEnergy
    case inLove
    case rebellious
    case sultry
    case heartbroken
    case restless
    case gospelPeace
    case christmas
    case lisa

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .melancholy: return "Melancholy"
        case .highEnergy: return "High Energy"
        case .inLove: return "In Love"
        case .rebellious: return "Rebellious"
        case .sultry: return "Sultry / Late Night"
        case .heartbroken: return "Heartbroken"
        case .restless: return "Routinely Restless"
        case .gospelPeace: return "Gospel Peace"
        case .christmas: return "Christmas"
        case .lisa: return "Lisa"
        }
    }

    var systemImage: String {
        switch self {
        case .melancholy: return "cloud.rain.fill"
        case .highEnergy: return "bolt.fill"
        case .inLove: return "heart.fill"
        case .rebellious: return "flame.fill"
        case .sultry: return "moon.stars.fill"
        case .heartbroken: return "heart.slash.fill"
        case .restless: return "road.lanes"
        case .gospelPeace: return "sun.max.fill"
        case .christmas: return "snowflake"
        case .lisa: return "music.mic"
        }
    }

    var tagline: String {
        switch self {
        case .melancholy: return "Wistful ballads & quiet reflections"
        case .highEnergy: return "Driving rhythms & electric fire"
        case .inLove: return "Tender vows & golden-era romance"
        case .rebellious: return "Leather-jacket swagger & raw grit"
        case .sultry: return "Midnight grooves & smoky vocals"
        case .heartbroken: return "Unfiltered ache & blue-hour confessions"
        case .restless: return "Highway rockabilly & Memphis soul"
        case .gospelPeace: return "Sacred harmonies & Graceland grace"
        case .christmas: return "Graceland holiday classics & winter warmth"
        case .lisa: return "Lisa Marie Presley solo & duet tracks"
        }
    }

    /// Synonyms used when matching free-text mood descriptions typed by the user.
    var searchSynonyms: [String] {
        switch self {
        case .melancholy:
            return ["melancholy", "sad", "blue", "down", "nostalgic", "wistful", "lonely", "gloomy"]
        case .highEnergy:
            return ["high energy", "energetic", "hype", "pump", "fast", "dance", "party", "upbeat", "excited"]
        case .inLove:
            return ["in love", "love", "romantic", "crush", "sweet", "wedding", "affection", "warm"]
        case .rebellious:
            return ["rebellious", "rebel", "angry", "defiant", "rock", "punk", "wild", "trouble", "attitude"]
        case .sultry:
            return ["sultry", "late night", "midnight", "sexy", "smooth", "chill", "moody", "cool"]
        case .heartbroken:
            return ["heartbroken", "heartbreak", "breakup", "cry", "crying", "hurt", "miss", "missing", "regret", "alone", "lonely"]
        case .restless:
            return ["restless", "antsy", "bored", "travel", "road", "drive", "wander", "edge"]
        case .gospelPeace:
            return ["gospel", "peace", "calm", "spiritual", "serene", "faith", "quiet", "hopeful", "relaxed"]
        case .christmas:
            return ["christmas", "holiday", "xmas", "santa", "winter", "snow", "merry", "jingle", "silent night", "bethlehem", "noel"]
        case .lisa:
            return ["lisa", "lisa marie", "storm", "grace", "lights out", "now what", "to whom it may concern"]
        }
    }
}

/// Filter allowing fans to spin Elvis, Lisa Marie, or the full Presley catalog.
enum ArtistFilter: String, CaseIterable, Identifiable {
    case all = "All Presley"
    case elvis = "Elvis"
    case lisaMarie = "Lisa Marie"

    var id: String { rawValue }

    func matches(artistName: String) -> Bool {
        switch self {
        case .all:
            return true
        case .elvis:
            return artistName.localizedCaseInsensitiveContains("Elvis Presley")
        case .lisaMarie:
            return artistName.localizedCaseInsensitiveContains("Lisa Marie Presley")
        }
    }
}
