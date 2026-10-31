import Foundation
import Testing
@testable import StickiesCore

private extension Library {
    /// `apply`, failing the test if the change can't be made.
    mutating func applied(_ change: LibraryChange) throws -> (reverse: LibraryChange, ops: [DiskOp]) {
        let result = apply(change)
        return try #require(result)
    }
}

/// Undo and redo are the same operation: applying a change returns its reverse.
@Suite struct UndoTests {
    /// A library on disk, with a Cooking folder holding notes, and the Inbox holding notes.
    func setUp(_ t: TempRoot) async throws -> (lib: Library, cooking: Folder.ID) {
        var lib = try LibraryLoader.load(root: t.root)
        let (cooking, mk) = lib.createFolder(named: "Cooking")
        var ops = mk
        for text in ["Dal\nlentils", "Miso cod\nmarinate", "Plan\nCooking plan"] {
            let id = lib.createNote(in: cooking, text: text)!
            ops += lib.persist(id)
        }
        for text in ["Plan\nInbox plan", "Taxes\nfile them"] {
            let id = lib.createNote(in: lib.inbox.id, text: text)!
            ops += lib.persist(id)
        }
        ops.append(.saveIndex(lib.index))
        await t.disk.run(ops)
        return (lib, cooking)
    }

    func id(_ title: String, _ lib: Library, in folder: Folder.ID) -> Note.ID {
        lib.folder(folder)!.notes.first { $0.title == title }!.id
    }

    @Test func undoingAMovePutsTheNoteAndItsFileBack() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let before = lib.folder(cooking)!.notes.map(\.id)
        let plan = id("Plan", lib, in: cooking)

        let undo = try #require(lib.placement(of: plan))
        await t.disk.run(lib.move(plan, to: lib.inbox.id))
        // Inbox already has a Plan.md, so it arrived with another name.
        #expect(t.exists("Inbox", "Plan 2.md"))

        let (redo, ops) = try lib.applied(undo)
        await t.disk.run(ops)
        #expect(lib.folder(cooking)!.notes.map(\.id) == before)
        #expect(t.exists("Cooking", "Plan.md"), "the name it had there")
        #expect(!t.exists("Inbox", "Plan 2.md"))

        let (again, redoOps) = try lib.applied(redo)
        await t.disk.run(redoOps)
        #expect(lib.folderOf(note: plan)?.kind == .inbox)
        #expect(t.exists("Inbox", "Plan 2.md"))
        #expect(again == undo)

        // What's on disk agrees, after a reload.
        let reloaded = try LibraryLoader.load(root: t.root)
        #expect(reloaded.inbox.notes.map(\.title).contains("Plan"))
        #expect(reloaded.folder(named: "Cooking")?.notes.count == 2)
    }

    @Test func undoingAMoveLeavesItsDateAlone() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let dal = id("Dal", lib, in: cooking)
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: t.file("Cooking", "Dal.md").path)

        let undo = try #require(lib.placement(of: dal))
        await t.disk.run(lib.move(dal, to: lib.archive.id))
        await t.disk.run(try lib.applied(undo).ops)

        let reloaded = try LibraryLoader.load(root: t.root)
        let note = try #require(reloaded.folder(named: "Cooking")?.notes.first { $0.title == "Dal" })
        #expect(abs(note.modified.timeIntervalSince(old)) < 1, "stale counting still sees the old date")
    }

    @Test func textTypedAfterAMoveIsKept() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let dal = id("Dal", lib, in: cooking)
        let undo = try #require(lib.placement(of: dal))
        await t.disk.run(lib.move(dal, to: lib.inbox.id))
        lib.setText(dal, "Dal\nlentils, and more lentils")
        await t.disk.run(try lib.applied(undo).ops)
        #expect(lib.folderOf(note: dal)?.id == cooking)
        #expect(lib.note(dal)?.text == "Dal\nlentils, and more lentils")
        #expect(try String(contentsOf: t.file("Cooking", "Dal.md"), encoding: .utf8) == "Dal\nlentils, and more lentils")
    }

    @Test func aRetitledNoteKeepsItsNewNameWhenMovedBack() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let dal = id("Dal", lib, in: cooking)
        let undo = try #require(lib.placement(of: dal))
        await t.disk.run(lib.move(dal, to: lib.inbox.id))
        lib.setText(dal, "Red lentils\nsoak")
        await t.disk.run(lib.persist(dal))
        await t.disk.run(try lib.applied(undo).ops)
        #expect(t.exists("Cooking", "Red lentils.md"))
        #expect(!t.exists("Cooking", "Dal.md"))
    }

    @Test func undoingTrashBringsTheSameFileBackOutOfTheTrash() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let before = lib.folder(cooking)!.notes.map(\.id)
        let miso = id("Miso cod", lib, in: cooking)
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: t.file("Cooking", "Miso cod.md").path)

        let undo = try #require(lib.restoration(of: miso))
        await t.disk.run(lib.trash(miso))
        #expect(!t.exists("Cooking", "Miso cod.md"))

        let (redo, ops) = try lib.applied(undo)
        await t.disk.run(ops)
        #expect(lib.folder(cooking)!.notes.map(\.id) == before, "same note, same place")
        #expect(t.exists("Cooking", "Miso cod.md"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: t.trashDir.path).isEmpty, "no copy left behind")
        let attrs = try FileManager.default.attributesOfItem(atPath: t.file("Cooking", "Miso cod.md").path)
        #expect(abs((attrs[.modificationDate] as! Date).timeIntervalSince(old)) < 1)

        // And redo trashes it again.
        await t.disk.run(try lib.applied(redo).ops)
        #expect(lib.note(miso) == nil)
        #expect(!t.exists("Cooking", "Miso cod.md"))
    }

    @Test func undoingTrashAfterTheTrashWasEmptiedWritesTheNoteAgain() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let miso = id("Miso cod", lib, in: cooking)
        let undo = try #require(lib.restoration(of: miso))
        await t.disk.run(lib.trash(miso))
        for item in try FileManager.default.contentsOfDirectory(at: t.trashDir, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: item)
        }
        await t.disk.run(try lib.applied(undo).ops)
        #expect(try String(contentsOf: t.file("Cooking", "Miso cod.md"), encoding: .utf8) == "Miso cod\nmarinate")
    }

    @Test func undoingTrashAfterItsFolderIsGoneUsesInbox() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let miso = id("Miso cod", lib, in: cooking)
        let undo = try #require(lib.restoration(of: miso))
        await t.disk.run(lib.trash(miso))
        await t.disk.run(lib.deleteFolder(cooking))
        await t.disk.run(try lib.applied(undo).ops)
        #expect(lib.folderOf(note: miso)?.kind == .inbox)
        #expect(t.exists("Inbox", "Miso cod.md"))
    }

    @Test func aTrashedNoteComesBackUnderTheFolderItsNameNow() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let miso = id("Miso cod", lib, in: cooking)
        let undo = try #require(lib.restoration(of: miso))
        await t.disk.run(lib.trash(miso))
        await t.disk.run(lib.renameFolder(cooking, to: "Food"))
        await t.disk.run(try lib.applied(undo).ops)
        #expect(t.exists("Food", "Miso cod.md"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: t.trashDir.path).isEmpty)
    }

    @Test func starterMarksComeBackWithTheNote() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let dal = id("Dal", lib, in: cooking)
        _ = lib.markSuggested([dal], in: cooking)
        #expect(lib.folder(cooking)?.filedByHand == 2)

        let undo = try #require(lib.placement(of: dal))
        await t.disk.run(lib.move(dal, to: lib.inbox.id))
        let (redo, ops) = try lib.applied(undo)
        await t.disk.run(ops)
        #expect(lib.folder(cooking)?.filedByHand == 2, "an undo isn't filing by hand")
        let reloaded = try LibraryLoader.load(root: t.root)
        #expect(reloaded.folder(named: "Cooking")?.filedByHand == 2, "and it's saved")

        // Redo takes the mark away again.
        _ = try lib.applied(redo)
        #expect(lib.folder(cooking)?.suggestedNotes.isEmpty == true)
    }

    @Test func undoingADeletedFolderBringsItAndItsNotesBack() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let (other, mk) = lib.createFolder(named: "Other")
        await t.disk.run(mk)
        let folder = lib.folder(cooking)!
        let inboxBefore = lib.inbox.notes.map(\.id)
        _ = lib.markSuggested([folder.notes[0].id], in: cooking)

        // In the order Board records them: last note first, then the folder.
        var undo = folder.notes.reversed().compactMap { lib.placement(of: $0.id) }
        undo.append(try #require(lib.restoration(ofFolder: cooking)))
        await t.disk.run(lib.deleteFolder(cooking))
        #expect(lib.folder(cooking) == nil)

        // Undo runs them backwards.
        for change in undo.reversed() {
            await t.disk.run(try lib.applied(change).ops)
        }
        #expect(lib.folder(cooking)?.notes.map(\.id) == folder.notes.map(\.id))
        #expect(lib.folder(cooking)?.color == folder.color)
        #expect(lib.folder(cooking)?.filedByHand == 2)
        #expect(lib.inbox.notes.map(\.id) == inboxBefore)
        #expect(lib.userFolders.map(\.id) == [cooking, other], "in its old place")
        #expect(t.exists("Cooking", "Dal.md"))
        #expect(try LibraryLoader.load(root: t.root).folder(named: "Cooking")?.notes.count == 3)
    }

    @Test func removingAFolderNeverLosesNotesFiledSince() async throws {
        let t = try TempRoot()
        var (lib, cooking) = try await setUp(t)
        let (reverse, ops) = try lib.applied(.removeFolder(cooking))
        await t.disk.run(ops)
        #expect(lib.inbox.notes.count == 5, "its notes went to Inbox")
        #expect(t.exists("Inbox", "Dal.md"))
        guard case .restoreFolder = reverse else { Issue.record("expected a folder to restore"); return }
    }

    @Test func aRestoredFolderTakesAFreeName() throws {
        var lib = Library.empty()
        let (cooking, _) = lib.createFolder(named: "Cooking")
        let undo = try #require(lib.restoration(ofFolder: cooking))
        _ = lib.deleteFolder(cooking)
        _ = lib.createFolder(named: "Cooking")
        _ = try lib.applied(undo)
        #expect(lib.folder(cooking)?.name == "Cooking 2")
    }

    @Test func aChangeWhoseNoteIsGoneDoesNothing() throws {
        var lib = Library.empty()
        let id = lib.createNote(in: lib.inbox.id, text: "Gone")!
        _ = lib.persist(id)
        let undo = try #require(lib.placement(of: id))
        _ = lib.trash(id)
        let before = lib
        let place = lib.apply(undo), trash = lib.apply(.trash(id))
        #expect(place == nil && trash == nil)
        #expect(lib == before)
    }

    @Test func aBlankNoteHasNothingToBringBack() {
        var lib = Library.empty()
        let id = lib.createNote(in: lib.inbox.id)!
        #expect(lib.restoration(of: id) == nil)
    }

    @Test func inboxAndArchiveCantBeRemoved() {
        var lib = Library.empty()
        let inbox = lib.apply(.removeFolder(lib.inbox.id)), archive = lib.apply(.removeFolder(lib.archive.id))
        #expect(inbox == nil && archive == nil)
    }

    @Test func notesAreStaleAfterSixtyDaysByDefault() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func note(_ days: Double) -> Note { Note(fileName: "a.md", text: "a", modified: now.addingTimeInterval(-days * 86_400)) }
        #expect(Staleness.defaultDays == 60)
        #expect(Staleness.allowedDays.contains(Staleness.defaultDays))
        #expect(!Staleness.isStale(note(59), in: .inbox, days: Staleness.defaultDays, now: now))
        #expect(Staleness.isStale(note(60), in: .inbox, days: Staleness.defaultDays, now: now))
    }
}
