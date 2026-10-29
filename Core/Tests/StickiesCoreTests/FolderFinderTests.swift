import Foundation
import Testing
@testable import StickiesCore

@Suite struct FolderFinderTests {
    /// Words only (no meaning model), so groups depend on shared words alone.
    let finder = FolderFinder(embedder: NoEmbedder())

    func notes(_ texts: [String]) -> [(id: UUID, text: String)] { texts.map { (UUID(), $0) } }

    let miso = ["Miso cod\nmiso, mirin, sake marinade overnight",
                "Miso soup\ndashi, miso, tofu, scallion",
                "Miso glaze\nmiso and honey for the salmon"]
    let avalanche = ["Avalanche forecast\nconsiderable danger above treeline, avalanche risk",
                     "Avalanche course\nbook the avalanche level 1 in December",
                     "Avalanche gear\nbeacon, probe, shovel; avalanche beacon batteries"]

    @Test func groupsNotesThatShareWords() {
        let input = notes(miso + avalanche + ["Renew passport before June"])
        let out = finder.propose(notes: input)
        #expect(out.count == 2)
        let groups = Set(out.map { Set($0.noteIDs) })
        #expect(groups.contains(Set(input[0..<3].map(\.id))))
        #expect(groups.contains(Set(input[3..<6].map(\.id))))
        #expect(Set(out.map(\.name)) == ["Miso", "Avalanche"])
        // The stray note stays out of every group.
        #expect(!out.flatMap(\.noteIDs).contains(input[6].id))
    }

    @Test func idIsTheGroupsFirstNote() {
        let input = notes(miso)
        let out = finder.propose(notes: input)
        #expect(out.first?.id == input[0].id)
        #expect(out.first?.noteIDs == input.map(\.id))
    }

    @Test func keepsTheNotesCapitals() {
        let out = finder.propose(notes: notes(["PPO run 3\nPPO lr 3e-4, clip 0.2", "PPO entropy\nPPO entropy collapsed early",
                                               "PPO baseline\nPPO vs SAC on the arm"]))
        #expect(out.first?.name == "PPO")
    }

    @Test func avoidsTakenNamesAndUnits() {
        let cups = ["Bread\n2 cup flour, miso butter", "Pancakes\n1 cup milk, miso caramel", "Rice\n1 cup rice, miso glaze"]
        let first = finder.propose(notes: notes(cups))
        #expect(first.first?.name == "Miso", "a unit like “cup” never names a folder")
        let second = finder.propose(notes: notes(cups), avoiding: ["miso"])
        #expect(second.first?.name != "Miso")
        #expect(second.first?.name != "Cup")
    }

    @Test func tooFewOrBlankNotesGiveNothing() {
        #expect(finder.propose(notes: notes(Array(miso.prefix(2)))).isEmpty)
        #expect(finder.propose(notes: notes(["", "  \n", "\n"])).isEmpty)
        #expect(finder.propose(notes: []).isEmpty)
    }

    @Test func nothingInCommonGivesNothing() {
        let out = finder.propose(notes: notes(["Renew passport", "Call the dentist", "Buy a birthday card", "Fix bike brakes"]))
        #expect(out.isEmpty)
    }

    /// The real model on the sample pile: at most `maxFolders`, every group big
    /// enough, no note in two groups.
    @Test func sampleNotesGiveSensibleGroups() throws {
        let sample = try SampleSet.load()
        let texts = sample.folders.flatMap { $0.notes.map(\.text) } + sample.inbox.map(\.text)
        let out = FolderFinder(embedder: WordVectorEmbedder()).propose(notes: notes(texts))
        #expect(!out.isEmpty && out.count <= FolderFinderConfig.standard.maxFolders)
        #expect(out.allSatisfy { $0.noteIDs.count >= FolderFinderConfig.standard.minNotes })
        let all = out.flatMap(\.noteIDs)
        #expect(all.count == Set(all).count)
        #expect(Set(out.map { $0.name.lowercased() }).count == out.count)
    }
}
