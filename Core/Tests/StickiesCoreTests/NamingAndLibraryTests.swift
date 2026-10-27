import Foundation
import Testing
@testable import StickiesCore

@Suite struct NamingTests {
    @Test func titleIsFirstNonEmptyLineWithoutHeadingMarks() {
        #expect(NoteNaming.title(from: "\n\n## Sim-to-real  \nbody") == "Sim-to-real")
        #expect(NoteNaming.title(from: "   \n  ") == "")
        #expect(NoteNaming.body(from: "\nTitle\nline 1\nline 2\n") == "line 1\nline 2")
    }

    @Test func fileNamesAreSafeAndReadable() {
        #expect(NoteNaming.baseName(for: "Q3/Q4: plan") == "Q3-Q4- plan")
        #expect(NoteNaming.baseName(for: "...hidden?") == "hidden?")
        #expect(NoteNaming.baseName(for: "") == "Untitled")
        #expect(NoteNaming.baseName(for: "tab\there") == "tab here")
        let long = String(repeating: "word ", count: 30)
        #expect(NoteNaming.baseName(for: long).count <= 60)
        #expect(!NoteNaming.baseName(for: long).hasSuffix(" "))
    }

    @Test func uniqueNamesIgnoreCase() {
        #expect(NoteNaming.uniqueFileName(base: "Plan", taken: []) == "Plan.md")
        #expect(NoteNaming.uniqueFileName(base: "Plan", taken: ["plan.md"]) == "Plan 2.md")
        #expect(NoteNaming.uniqueFileName(base: "Plan", taken: ["Plan.md", "Plan 2.md"]) == "Plan 3.md")
    }

    @Test func numberedTitlesDontChurn() {
        #expect(NoteNaming.fileName("Plan 2.md", matches: "Plan"))
        #expect(NoteNaming.fileName("Week 2.md", matches: "Week 2"))
        #expect(!NoteNaming.fileName("plan.md", matches: "Plan"))
    }
}

@Suite struct LibraryTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func withFolder() -> (Library, Folder.ID) {
        var lib = Library.empty()
        let (id, _) = lib.createFolder(named: "Robotics")
        return (lib, id)
    }

    @Test func emptyHasInboxFirstArchiveLast() {
        let lib = Library.empty()
        #expect(lib.folders.map(\.name) == ["Inbox", "Archive"])
    }

    @Test func newNoteTouchesDiskOnlyOnceItHasText() {
        var lib = Library.empty()
        let id = lib.createNote(in: lib.inbox.id, now: now)!
        #expect(lib.persist(id).isEmpty)
        lib.setText(id, "Call dentist\nre crown", now: now)
        let ops = lib.persist(id)
        #expect(ops.first == .write(folder: "Inbox", file: "Call dentist.md", text: "Call dentist\nre crown", modified: nil))
        #expect(lib.note(id)?.fileName == "Call dentist.md")
        #expect(lib.note(id)?.dirty == false)
        #expect(lib.persist(id).isEmpty, "nothing to write when clean")
    }

    @Test func titleChangeRenames() {
        var lib = Library.empty()
        let id = lib.createNote(in: lib.inbox.id, text: "Old", now: now)!
        _ = lib.persist(id)
        lib.setText(id, "New title\nbody", now: now)
        let ops = lib.persist(id)
        #expect(ops.contains(.rename(folder: "Inbox", from: "Old.md", to: "New title.md")))
        // Same title again: plain write, no rename.
        lib.setText(id, "New title\nbody 2", now: now)
        #expect(lib.persist(id).count == 1)
    }

    @Test func duplicateTitlesGetNumbers() {
        var lib = Library.empty()
        let a = lib.createNote(in: lib.inbox.id, text: "Groceries", now: now)!
        _ = lib.persist(a)
        let b = lib.createNote(in: lib.inbox.id, text: "Groceries", now: now)!
        _ = lib.persist(b)
        #expect(lib.note(b)?.fileName == "Groceries 2.md")
    }

    @Test func blankNotesAreDiscarded() {
        var lib = Library.empty()
        let id = lib.createNote(in: lib.inbox.id, now: now)!
        #expect(lib.discardIfBlank(id).isEmpty)
        #expect(lib.note(id) == nil)
    }

    @Test func moveRenamesOnCollisionAndKeepsDirtyText() {
        var (lib, robotics) = withFolder()
        let a = lib.createNote(in: robotics, text: "Plan", now: now)!
        _ = lib.persist(a)
        let b = lib.createNote(in: lib.inbox.id, text: "Plan", now: now)!
        _ = lib.persist(b)
        lib.setText(b, "Plan\nmore", now: now)
        let ops = lib.move(b, to: robotics)
        #expect(ops.contains(.move(from: "Inbox", to: "Robotics", file: "Plan.md", newFile: "Plan 2.md")))
        #expect(ops.contains(.write(folder: "Robotics", file: "Plan 2.md", text: "Plan\nmore", modified: nil)))
        #expect(lib.folder(robotics)?.notes.first?.id == b)
        #expect(lib.inbox.notes.isEmpty)
    }

    @Test func reorderChangesOrderAndSavesIndex() {
        var lib = Library.empty()
        let ids = ["A", "B", "C"].map { t -> Note.ID in
            let id = lib.createNote(in: lib.inbox.id, text: t, now: now)!
            _ = lib.persist(id)
            return id
        }
        // Order is C, B, A (new notes go on top).
        let ops = lib.reorder(ids[2], to: 2)
        #expect(lib.inbox.notes.map(\.title) == ["B", "A", "C"])
        #expect(ops.count == 1)
        #expect(lib.reorder(ids[2], to: 2).isEmpty, "no-op reorder writes nothing")
    }

    @Test func trashOnlyTouchesDiskForSavedNotes() {
        var lib = Library.empty()
        let id = lib.createNote(in: lib.inbox.id, text: "x", now: now)!
        _ = lib.persist(id)
        #expect(lib.trash(id).first == .trashNote(folder: "Inbox", file: "x.md"))
        #expect(lib.inbox.notes.isEmpty)
    }

    @Test func foldersAreUniqueColoredAndBeforeArchive() {
        var lib = Library.empty()
        let (a, _) = lib.createFolder(named: "Cooking")
        let (b, _) = lib.createFolder(named: "cooking")
        #expect(lib.folder(b)?.name == "cooking 2")
        #expect(lib.folder(a)?.color != lib.folder(b)?.color)
        #expect(lib.folders.last?.kind == .archive)
        let (c, _) = lib.createFolder(named: "  ")
        #expect(lib.folder(c)?.name == "New Folder")
    }

    @Test func renameFolderAndProtectedFolders() {
        var (lib, robotics) = withFolder()
        #expect(lib.renameFolder(robotics, to: "Robot Learning").first == .renameFolder(from: "Robotics", to: "Robot Learning"))
        #expect(lib.renameFolder(lib.inbox.id, to: "Other").isEmpty)
        #expect(lib.deleteFolder(lib.archive.id).isEmpty)
        #expect(lib.setColor(lib.inbox.id, .clay).isEmpty)
    }

    @Test func deletingAFolderMovesNotesToInbox() {
        var (lib, robotics) = withFolder()
        let id = lib.createNote(in: robotics, text: "PPO run", now: now)!
        _ = lib.persist(id)
        let ops = lib.deleteFolder(robotics)
        #expect(ops.contains(.move(from: "Robotics", to: "Inbox", file: "PPO run.md", newFile: "PPO run.md")))
        #expect(ops.contains(.trashFolder("Robotics")))
        #expect(lib.inbox.notes.map(\.id) == [id])
        #expect(lib.folder(robotics) == nil)
    }

    @Test func moveFolderKeepsInboxAndArchiveFixed() {
        var lib = Library.empty()
        let (a, _) = lib.createFolder(named: "A")
        _ = lib.createFolder(named: "B")
        _ = lib.moveFolder(a, to: 5)
        #expect(lib.folders.map(\.name) == ["Inbox", "B", "A", "Archive"])
    }

    @Test func importSkipsDuplicatesAndBlanksAndKeepsDates() {
        var lib = Library.empty()
        let old = now.addingTimeInterval(-30 * 86_400)
        let items = [
            ImportedSticky(id: "u1", text: "Groceries\nmilk", modified: old),
            ImportedSticky(id: "u2", text: "  ", modified: now),
            ImportedSticky(id: "u3", text: "Newest", modified: now),
        ]
        let (added, ops) = lib.addImported(items)
        #expect(added == 2)
        #expect(ops.contains(.write(folder: "Inbox", file: "Groceries.md", text: "Groceries\nmilk", modified: old)))
        #expect(lib.inbox.notes.map(\.title) == ["Newest", "Groceries"])
        #expect(lib.addImported(items).added == 0)
    }
}

@Suite struct StalenessTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func staleAfterThresholdButNotInArchive() {
        let n = Note(fileName: "a.md", text: "a", modified: now.addingTimeInterval(-15 * 86_400))
        #expect(Staleness.isStale(n, in: .user, days: 14, now: now))
        #expect(Staleness.isStale(n, in: .inbox, days: 14, now: now))
        #expect(!Staleness.isStale(n, in: .archive, days: 14, now: now))
        #expect(!Staleness.isStale(n, in: .user, days: 30, now: now))
        let unsaved = Note(fileName: "", text: "a", modified: .distantPast)
        #expect(!Staleness.isStale(unsaved, in: .user, days: 14, now: now))
    }

    @Test func ageLabels() {
        func age(_ d: Double) -> String { Staleness.ageLabel(now.addingTimeInterval(-d * 86_400), now: now) }
        #expect(age(0) == "today")
        #expect(age(1) == "yesterday")
        #expect(age(5) == "5 days ago")
        #expect(age(21) == "3 weeks ago")
        #expect(age(120) == "4 months ago")
    }
}
