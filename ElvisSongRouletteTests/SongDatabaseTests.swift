import Foundation
import Testing
@testable import ElvisSongRoulette

struct SongDatabaseTests {
    private var database: SongDatabase {
        SongDatabase()
    }

    @Test func loadsCuratedCatalogIncludingElvisAndLisaMarie() {
        let db = database
        #expect(!db.songs.isEmpty)
        #expect(db.songs.contains(where: { $0.artist == "Elvis Presley" }))
        #expect(db.songs.contains(where: { $0.artist == "Lisa Marie Presley" }))
        #expect(db.songs.contains(where: { $0.id == "elvis-lisa-in-the-ghetto" }))
    }

    @Test func melancholyMoodMatchesExpectedBlueprintTracks() {
        let matches = database.matchingSongs(mood: .melancholy)
        let titles = Set(matches.map(\.title))
        #expect(titles.contains("Always on My Mind"))
        #expect(titles.contains("Lights Out"))
    }

    @Test func rebelliousMoodMatchesExpectedBlueprintTracks() {
        let matches = database.matchingSongs(mood: .rebellious)
        let titles = Set(matches.map(\.title))
        #expect(titles.contains("Trouble"))
        #expect(titles.contains("Idiot"))
        #expect(titles.contains("Jailhouse Rock"))
    }

    @Test func freeTextQueryMatchesSynonymsAndSessionLocations() {
        let lateNight = database.matchingSongs(mood: nil, query: "late night")
        #expect(!lateNight.isEmpty)

        let graceland = database.matchingSongs(mood: nil, query: "Graceland")
        #expect(graceland.contains(where: { $0.title == "Way Down" }))
    }

    @Test func artistFilterIsolatesLisaMarieTracks() {
        let lisaMatches = database.matchingSongs(mood: nil, artistFilter: .lisaMarie)
        #expect(!lisaMatches.isEmpty)
        #expect(lisaMatches.allSatisfy { $0.artist.contains("Lisa Marie Presley") })
    }

    @Test func spinAvoidsImmediateRepeatWhenMultipleCandidatesExist() {
        let db = database
        let candidates = db.matchingSongs(mood: .highEnergy)
        #expect(candidates.count > 1)
        let excluded = candidates[0].id
        for _ in 0..<10 {
            let pick = db.spin(mood: .highEnergy, excludingID: excluded)
            #expect(pick != nil)
            #expect(pick?.id != excluded)
        }
    }

    @Test func loadsFTDCollectorCatalog() {
        let ftd = FTDCatalog()
        #expect(ftd.releases.count >= 230)
        #expect(ftd.releases.first?.catalogNumber == "#001")
        #expect(ftd.releases.first?.title == "Burbank 68")
    }
}
