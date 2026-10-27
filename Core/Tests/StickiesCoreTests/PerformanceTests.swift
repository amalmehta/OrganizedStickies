import Foundation
import Testing
@testable import StickiesCore

/// Budgets at roughly 10× today's scale. Main-thread work (Library edits)
/// must stay far under one 16 ms frame; background work must finish in seconds.
@Suite struct PerformanceTests {
    func time(_ body: () throws -> Void) rethrows -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        try body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    }

    @Test func editsOnABigFolderAreInstant() {
        var lib = Library.empty()
        var ids: [Note.ID] = []
        for i in 0..<500 {
            let id = lib.createNote(in: lib.inbox.id, text: "Note \(i)\nsome body text about reward models and lentils")!
            _ = lib.persist(id)
            ids.append(id)
        }
        let target = ids[250]
        let keystroke = time { lib.setText(target, "Note 250 edited\nmore") }
        let save = time { _ = lib.persist(target) }
        let (folder, _) = lib.createFolder(named: "Big")
        let move = time { _ = lib.move(ids[10], to: folder) }
        let reorder = time { _ = lib.reorder(ids[400], to: 0) }
        #expect(keystroke < 5, "keystroke \(keystroke) ms")
        #expect(save < 16, "save planning \(save) ms")
        #expect(move < 16, "move \(move) ms")
        #expect(reorder < 16, "reorder \(reorder) ms")
    }

    @Test func loadingAThousandNotesTakesUnderASecond() throws {
        let t = try TempRoot()
        let fm = FileManager.default
        for f in 0..<10 {
            let dir = t.root.appendingPathComponent("Folder \(f)")
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for n in 0..<100 {
                try "Note \(n)\n\(String(repeating: "word ", count: 40))".write(to: dir.appendingPathComponent("Note \(n).md"), atomically: false, encoding: .utf8)
            }
        }
        var lib: Library?
        let ms = try time { lib = try LibraryLoader.load(root: t.root) }
        #expect(lib?.allNotes.count == 1000)
        #expect(ms < 1000, "load \(ms) ms")
    }

    @Test func sortingTwoHundredInboxNotesTakesSeconds() throws {
        let sample = try SampleSet.load()
        let candidates = sample.folders.map { SortCandidate(name: $0.name, notes: $0.notes.map(\.text)) }
        let notes = (0..<200).map { i in (id: UUID(), text: sample.inbox[i % sample.inbox.count].text + " \(i)") }
        let sorter = Sorter(embedder: AppleSentenceEmbedder())
        var out: [UUID: SortOutcome] = [:]
        let ms = time { out = sorter.suggest(notes: notes, folders: candidates) }
        #expect(out.count == 200)
        #expect(ms < 10_000, "sort \(ms) ms")
        print("perf: sorted 200 notes against 48 filed in \(Int(ms)) ms")
    }
}
