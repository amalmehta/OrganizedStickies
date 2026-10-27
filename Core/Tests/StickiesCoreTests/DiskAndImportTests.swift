import Foundation
import Testing
@testable import StickiesCore

/// A fresh temp root per test, and a local "trash" so tests never fill the Finder Trash.
struct TempRoot {
    let root: URL
    let trashDir: URL
    let disk: NoteDisk

    init() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("OSTests-\(UUID().uuidString)")
        root = base.appendingPathComponent("Organized Stickies")
        trashDir = base.appendingPathComponent("Trash")
        try FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true)
        let t = trashDir
        disk = NoteDisk(root: root) { url in
            try FileManager.default.moveItem(at: url, to: t.appendingPathComponent(UUID().uuidString + url.lastPathComponent))
        }
    }

    func file(_ folder: String, _ name: String) -> URL { root.appendingPathComponent(folder).appendingPathComponent(name) }
    func exists(_ folder: String, _ name: String) -> Bool { FileManager.default.fileExists(atPath: file(folder, name).path) }
}

@Suite struct DiskRoundTripTests {
    @Test func editsSurviveReload() async throws {
        let t = try TempRoot()
        var lib = try LibraryLoader.load(root: t.root)
        let (robotics, mk) = lib.createFolder(named: "Robotics")
        var ops = mk
        let a = lib.createNote(in: lib.inbox.id, text: "First\none")!
        ops += lib.persist(a)
        let b = lib.createNote(in: robotics, text: "Second")!
        ops += lib.persist(b)
        lib.setText(a, "First renamed\none")
        ops += lib.persist(a)
        ops += lib.move(a, to: robotics, at: 1)
        _ = lib.setColor(robotics, .clay)
        ops += [.saveIndex(lib.index)]
        let failures = await t.disk.run(ops)
        #expect(failures.isEmpty)

        #expect(t.exists("Robotics", "First renamed.md"))
        #expect(!t.exists("Inbox", "First.md"))
        let reloaded = try LibraryLoader.load(root: t.root)
        #expect(reloaded.folders.map(\.name) == ["Inbox", "Robotics", "Archive"])
        let f = try #require(reloaded.folder(named: "Robotics"))
        #expect(f.color == .clay)
        #expect(f.notes.map(\.text) == ["Second", "First renamed\none"])
    }

    @Test func reloadKeepsIDsAndUnsavedText() async throws {
        let t = try TempRoot()
        var lib = try LibraryLoader.load(root: t.root)
        let a = lib.createNote(in: lib.inbox.id, text: "A")!
        let b = lib.createNote(in: lib.inbox.id, text: "B")!
        #expect(await t.disk.run(lib.persist(a) + lib.persist(b)).isEmpty)
        lib.setText(b, "B typed but not saved")
        let draft = lib.createNote(in: lib.inbox.id)!
        // Someone edits A in another app.
        try "A edited elsewhere".write(to: t.file("Inbox", "A.md"), atomically: true, encoding: .utf8)
        let merged = lib.merged(withDisk: try LibraryLoader.load(root: t.root))
        #expect(merged.inbox.id == lib.inbox.id)
        #expect(merged.note(a)?.text == "A edited elsewhere")
        #expect(merged.note(b)?.text == "B typed but not saved")
        #expect(merged.note(draft) != nil)
    }

    @Test func caseOnlyRename() async throws {
        let t = try TempRoot()
        var lib = try LibraryLoader.load(root: t.root)
        let id = lib.createNote(in: lib.inbox.id, text: "plan")!
        var ops = lib.persist(id)
        lib.setText(id, "Plan")
        ops += lib.persist(id)
        #expect(await t.disk.run(ops).isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: t.root.appendingPathComponent("Inbox").path)
        #expect(names == ["Plan.md"])
    }

    @Test func trashAndDeleteFolderGoToTrashNotOblivion() async throws {
        let t = try TempRoot()
        var lib = try LibraryLoader.load(root: t.root)
        let (folder, mk) = lib.createFolder(named: "Temp")
        let id = lib.createNote(in: folder, text: "keep me")!
        let other = lib.createNote(in: folder, text: "trash me")!
        var ops = mk + lib.persist(id) + lib.persist(other)
        ops += lib.trash(other)
        ops += lib.deleteFolder(folder)
        #expect(await t.disk.run(ops).isEmpty)
        #expect(t.exists("Inbox", "keep me.md"))
        #expect(!FileManager.default.fileExists(atPath: t.root.appendingPathComponent("Temp").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: t.trashDir.path).count == 2)
    }

    @Test func externalFilesAndMissingIndex() async throws {
        let t = try TempRoot()
        _ = try LibraryLoader.load(root: t.root)
        let fm = FileManager.default
        try fm.createDirectory(at: t.root.appendingPathComponent("From Finder"), withIntermediateDirectories: true)
        try "older".write(to: t.file("From Finder", "a.md"), atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -86_400)], ofItemAtPath: t.file("From Finder", "a.md").path)
        try "newer".write(to: t.file("From Finder", "b.txt"), atomically: true, encoding: .utf8)
        try "ignored".write(to: t.file("From Finder", "image.png"), atomically: true, encoding: .utf8)
        try "hidden".write(to: t.file("From Finder", ".DS_Store"), atomically: true, encoding: .utf8)
        try Data([0xff, 0xfe, 0x41]).write(to: t.file("Inbox", "bad bytes.md"))
        try "{not json".write(to: t.root.appendingPathComponent(LibraryIndex.fileName), atomically: true, encoding: .utf8)

        let lib = try LibraryLoader.load(root: t.root)
        let f = try #require(lib.folder(named: "From Finder"))
        #expect(f.notes.map(\.text) == ["newer", "older"], "unknown notes: newest first")
        #expect(f.kind == .user)
        #expect(lib.inbox.notes.count == 1, "invalid UTF-8 still loads")
    }

    @Test func failuresAreReportedNotThrown() async throws {
        let t = try TempRoot()
        _ = try LibraryLoader.load(root: t.root)
        let failures = await t.disk.run([
            .rename(folder: "Inbox", from: "missing.md", to: "x.md"),
            .write(folder: "Inbox", file: "ok.md", text: "ok", modified: nil),
        ])
        #expect(failures.count == 1)
        #expect(t.exists("Inbox", "ok.md"), "later ops still run")
    }

    @Test func sampleDataWritesAndLoads() throws {
        let t = try TempRoot()
        let sample = try SampleSet.load()
        try sample.write(to: t.root)
        let lib = try LibraryLoader.load(root: t.root)
        #expect(lib.userFolders.count == sample.folders.count)
        #expect(lib.inbox.notes.count == sample.inbox.count)
        #expect(lib.archive.notes.count == sample.archive.count)
        #expect(lib.folder(named: "Cooking")?.color == .clay)
        // Writing again doesn't duplicate.
        try sample.write(to: t.root)
        #expect(try LibraryLoader.load(root: t.root).inbox.notes.count == sample.inbox.count)
    }
}

@Suite struct ImporterTests {
    var fixtures: URL { Bundle.module.url(forResource: "Fixtures", withExtension: nil)!.appendingPathComponent("Stickies") }

    @Test func readsRtfdNotesAsPlainText() throws {
        let notes = try StickiesImporter.read(from: fixtures)
        #expect(notes.count == 3)
        let ppo = try #require(notes.first { $0.id == "B2" })
        #expect(ppo.text == "PPO reward shaping\nthe policy keeps exploiting the contact sensor bonus")
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.component(.year, from: ppo.modified) == 2026 && cal.component(.month, from: ppo.modified) == 9)
        #expect(notes.first { $0.id == "C3" }?.text == "")
    }

    @Test func missingDirectoryIsAClearError() {
        #expect(throws: StickiesImporter.ImportError.self) {
            try StickiesImporter.read(from: URL(fileURLWithPath: "/nonexistent/Stickies"))
        }
    }
}
