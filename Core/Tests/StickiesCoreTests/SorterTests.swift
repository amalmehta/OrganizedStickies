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

@Suite struct StreamingSorterTests {
    @Test func batchesGiveTheSameAnswersInOrder() throws {
        let sample = try SampleSet.load()
        let candidates = sample.folders.map { SortCandidate(name: $0.name, notes: $0.notes.map(\.text)) }
        let notes = sample.inbox.map { (id: UUID(), text: $0.text) }
        let sorter = Sorter(embedder: AppleSentenceEmbedder())
        let whole = sorter.suggest(notes: notes, folders: candidates)
        var streamed: [UUID: SortOutcome] = [:]
        var order: [UUID] = []
        sorter.suggest(notes: notes, folders: candidates, batchSize: 5) { batch in
            #expect(batch.count <= 5)
            order += notes.map(\.id).filter { batch[$0] != nil }
            streamed.merge(batch) { _, new in new }
        }
        // Same decisions; scores can differ in the last bits because word
        // weights are summed in dictionary order.
        #expect(streamed.count == whole.count)
        for (id, w) in whole {
            switch (w, streamed[id]) {
            case let (.suggest(f1, s1, r1), .suggest(f2, s2, r2)?):
                #expect(f1 == f2)
                #expect(r1 == r2)
                #expect(abs(s1 - s2) < 1e-9)
            case let (.noClearMatch(r1), .noClearMatch(r2)?):
                #expect(r1 == r2)
            default:
                Issue.record("outcome differs for a note")
            }
        }
        #expect(order == notes.map(\.id), "batches arrive top to bottom")
    }

    /// A stand-in model that takes a fixed time per text, so the test
    /// measures the batching, not the machine's load.
    struct SlowFakeEmbedder: SentenceEmbedder {
        func vector(for text: String) -> [Double]? {
            Thread.sleep(forTimeInterval: 0.005)
            var h = Hasher(); h.combine(text)
            let seed = UInt64(bitPattern: Int64(h.finalize()))
            return (0..<16).map { Double((seed >> UInt64($0 * 4)) & 0xF) - 7.5 }
        }
    }

    /// The first cards get their suggestion while the rest are still being
    /// worked out. With the fake model each note costs 5 ms, so the gap
    /// between the first and last batch is at least the 188 notes after the
    /// first batch × 5 ms, whatever else the Mac is doing.
    @Test func firstBatchArrivesLongBeforeTheLast() throws {
        let sample = try SampleSet.load()
        let candidates = sample.folders.map { SortCandidate(name: $0.name, notes: $0.notes.map(\.text)) }
        let notes = (0..<200).map { i in (id: UUID(), text: sample.inbox[i % sample.inbox.count].text + " \(i)") }
        let sorter = Sorter(embedder: SlowFakeEmbedder())
        var times: [UInt64] = []
        sorter.suggest(notes: notes, folders: candidates, batchSize: 12) { _ in times.append(DispatchTime.now().uptimeNanoseconds) }
        #expect(times.count == 17)
        let gap = Double((times.last ?? 0) - (times.first ?? 0)) / 1e6
        #expect(gap >= 188 * 5 * 0.95, "first and last batch \(gap) ms apart")
    }
}
