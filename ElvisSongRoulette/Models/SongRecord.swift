import Foundation

/// A single track entry from the bundled session ledger database.
struct SongRecord: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let year: Int
    let era: String
    let moods: [Mood]
    let keywords: [String]
    let energy: Int
    let appleMusicQuery: String
    let appleMusicAvailable: Bool?
    let session: SessionData

    var isOnAppleMusic: Bool {
        appleMusicAvailable ?? true
    }

    var isLisaMarie: Bool {
        artist.localizedCaseInsensitiveContains("Lisa Marie")
    }
}

/// Deep recording session metadata derived from official discographies and session ledgers.
struct SessionData: Codable, Hashable {
    let date: String
    let location: String
    let producer: String
    let musicians: [MusicianCredit]
    let backingVocals: [String]
    let chartPeak: String
    let backstory: String
}

/// Individual instrumentalist or vocalist credit from a recording session.
struct MusicianCredit: Codable, Hashable, Identifiable {
    var id: String { "\(name)-\(role)" }
    let name: String
    let role: String
}
