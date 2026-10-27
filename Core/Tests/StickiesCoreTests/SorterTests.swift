import Foundation
import Testing
@testable import StickiesCore

/// No meaning model: word overlap only, deterministic.
struct NoEmbedder: SentenceEmbedder {
    func vector(for text: String) -> [Double]? { nil }
}

@Suite struct SorterTests {
    let folders = [
        SortCandidate(name: "Cooking", notes: ["Dal for 6\nlentils, cumin, ginger, garlic", "Short ribs\nbraise with miso and ginger"]),
        SortCandidate(name: "Mountains", notes: ["Avalanche forecast\nconsiderable above treeline", "Ice screws\nsharpen before the trip"]),
    ]

    @Test func clearWordOverlapSuggests() {
        let s = Sorter(embedder: NoEmbedder())
        let id = UUID()
        let out = s.suggest(notes: [(id, "Miso glaze\nginger, garlic and miso for the ribs")], folders: folders)
        guard case let .suggest(folder, _, reason)? = out[id] else { Issue.record("expected a suggestion"); return }
        #expect(folder == "Cooking")
        #expect(reason.contains("miso") || reason.contains("ginger"))
    }

    @Test func shortNoteWithNoSharedWordsIsNoMatch() {
        let s = Sorter(embedder: NoEmbedder())
        let id = UUID()
        let out = s.suggest(notes: [(id, "call mom")], folders: folders)
        guard case let .noClearMatch(reason)? = out[id] else { Issue.record("expected no match"); return }
        #expect(reason.contains("2 words"))
    }

    @Test func noFoldersExplainsWhatToDo() {
        let s = Sorter(embedder: NoEmbedder())
        let id = UUID()
        let out = s.suggest(notes: [(id, "anything at all")], folders: [])
        #expect(out[id] == .noClearMatch(reason: "Make a folder first. Sorting needs somewhere to send notes."))
    }

    @Test func emptyAndHugeNotesDontCrash() {
        let s = Sorter(embedder: AppleSentenceEmbedder())
        let huge = String(repeating: "ginger garlic lentils ", count: 5_000)
        let ids = [UUID(), UUID(), UUID()]
        let out = s.suggest(notes: [(ids[0], ""), (ids[1], huge), (ids[2], "🍋🍋 ...")], folders: folders)
        #expect(out.count == 3)
        #expect(out[ids[1]]?.folder == "Cooking")
    }

    @Test func folderNameAloneCanMatch() {
        let s = Sorter(embedder: NoEmbedder())
        let id = UUID()
        let out = s.suggest(notes: [(id, "mountains trip in March")], folders: folders)
        #expect(out[id]?.folder == "Mountains")
    }

    /// The done criterion from the spec, on the held-out half of the sample:
    /// at least 90% of shown suggestions right, 60%+ coverage of 8+ word notes.
    @Test func meetsDoneCriterionOnHeldOutSample() throws {
        let sample = try SampleSet.load()
        let candidates = sample.folders.map { SortCandidate(name: $0.name, notes: $0.notes.map(\.text)) }
        let check = sample.inbox.filter { $0.split == "check" }
        let sorter = Sorter(embedder: AppleSentenceEmbedder())
        let analyses = sorter.analyze(notes: check.map(\.text), folders: candidates)
        var shown = 0, right = 0, longWithHome = 0, covered = 0
        for (n, a) in zip(check, analyses) {
            let long = a.wordCount > 7
            if long && n.expected != nil { longWithHome += 1 }
            guard let f = sorter.decide(a).folder else { continue }
            shown += 1
            if f == n.expected { right += 1 }
            if long && n.expected != nil { covered += 1 }
        }
        #expect(shown > 0)
        #expect(Double(right) / Double(shown) >= 0.9, "precision \(right)/\(shown)")
        #expect(Double(covered) / Double(longWithHome) >= 0.6, "coverage \(covered)/\(longWithHome)")
    }

    @Test func termsAreLemmatizedWithoutFiller() {
        let t = TextAnalysis.terms("The robots were running the policies")
        #expect(t.contains("robot"))
        #expect(!t.contains("the"))
    }
}
