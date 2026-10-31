import Foundation

/// One change to the library that undo or redo can make.
public enum LibraryChange: Sendable, Equatable {
    /// Put a note in a folder at a position, with the file name and starter
    /// mark it had there.
    case place(Note.ID, folder: Folder.ID, position: Int, suggested: Bool, fileName: String)
    /// Bring back a trashed note. `folderName` is where it was when trashed.
    case restore(Note, folder: Folder.ID, folderName: String, position: Int, suggested: Bool)
    case trash(Note.ID)
    case removeFolder(Folder.ID)
    case restoreFolder(Folder, position: Int)
}

/// The in-memory truth: folders in order, notes in order. Every edit returns
/// the `DiskOp`s that make the disk match, so the UI never waits on I/O and
/// the logic is testable without touching a disk.
public struct Library: Sendable, Equatable {
    public static let inboxName = "Inbox"
    public static let archiveName = "Archive"

    /// Inbox first, then user folders, Archive last.
    public var folders: [Folder]
    public var importedStickies: Set<String>

    public init(folders: [Folder], importedStickies: Set<String> = []) {
        self.folders = folders
        self.importedStickies = importedStickies
        normalize()
    }

    public static func empty() -> Library {
        Library(folders: [
            Folder(name: inboxName, color: .paper),
            Folder(name: archiveName, color: .stone),
        ])
    }

    // MARK: Lookup

    public var inbox: Folder { folders.first { $0.kind == .inbox }! }
    public var archive: Folder { folders.first { $0.kind == .archive }! }
    public var userFolders: [Folder] { folders.filter { $0.kind == .user } }

    public func folderIndex(_ id: Folder.ID) -> Int? { folders.firstIndex { $0.id == id } }
    public func folder(_ id: Folder.ID) -> Folder? { folders.first { $0.id == id } }
    public func folder(named name: String) -> Folder? { folders.first { $0.name == name } }

    public func location(of noteID: Note.ID) -> (folder: Int, note: Int)? {
        for (fi, f) in folders.enumerated() {
            if let ni = f.notes.firstIndex(where: { $0.id == noteID }) { return (fi, ni) }
        }
        return nil
    }

    public func note(_ id: Note.ID) -> Note? {
        guard let l = location(of: id) else { return nil }
        return folders[l.folder].notes[l.note]
    }

    public func folderOf(note id: Note.ID) -> Folder? {
        location(of: id).map { folders[$0.folder] }
    }

    public var allNotes: [Note] { folders.flatMap(\.notes) }

    public var index: LibraryIndex {
        LibraryIndex(
            folders: folders.map { f in
                let suggested = f.notes.filter { $0.isOnDisk && f.suggestedNotes.contains($0.id) }.map(\.fileName)
                return .init(name: f.name, color: f.color, order: f.notes.compactMap { $0.isOnDisk ? $0.fileName : nil },
                             suggested: suggested.isEmpty ? nil : suggested)
            },
            importedStickies: importedStickies.sorted()
        )
    }

    // MARK: Notes

    /// A new, empty note at the top of a folder. Nothing touches disk until
    /// it has text and is persisted.
    public mutating func createNote(in folderID: Folder.ID, text: String = "", now: Date = .now) -> Note.ID? {
        guard let fi = folderIndex(folderID) else { return nil }
        let note = Note(fileName: "", text: text, modified: now, dirty: !text.isEmpty)
        folders[fi].notes.insert(note, at: 0)
        return note.id
    }

    /// Change text in memory only. Call `persist` later (debounced).
    public mutating func setText(_ id: Note.ID, _ text: String, now: Date = .now) {
        guard let l = location(of: id), folders[l.folder].notes[l.note].text != text else { return }
        folders[l.folder].notes[l.note].text = text
        folders[l.folder].notes[l.note].modified = now
        folders[l.folder].notes[l.note].dirty = true
    }

    /// Write a dirty note, renaming its file if the title changed.
    public mutating func persist(_ id: Note.ID) -> [DiskOp] {
        guard let l = location(of: id) else { return [] }
        var note = folders[l.folder].notes[l.note]
        guard note.dirty else { return [] }
        let folderName = folders[l.folder].name
        let base = NoteNaming.baseName(for: note.text)
        var ops: [DiskOp] = []

        if !note.isOnDisk {
            if note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
            note.fileName = NoteNaming.uniqueFileName(base: base, taken: takenNames(in: l.folder, except: note.id))
            ops.append(.write(folder: folderName, file: note.fileName, text: note.text, modified: nil))
            ops.append(.saveIndex(index(updating: l, with: note)))
        } else if !NoteNaming.fileName(note.fileName, matches: base) {
            let newName = NoteNaming.uniqueFileName(base: base, taken: takenNames(in: l.folder, except: note.id))
            ops.append(.rename(folder: folderName, from: note.fileName, to: newName))
            note.fileName = newName
            ops.append(.write(folder: folderName, file: newName, text: note.text, modified: nil))
            ops.append(.saveIndex(index(updating: l, with: note)))
        } else {
            ops.append(.write(folder: folderName, file: note.fileName, text: note.text, modified: nil))
        }
        note.dirty = false
        folders[l.folder].notes[l.note] = note
        return ops
    }

    /// Persist every dirty note (before quitting, reloading, switching away).
    public mutating func persistAll() -> [DiskOp] {
        allNotes.filter(\.dirty).flatMap { persist($0.id) }
    }

    /// When editing ends on a blank note: drop it (and its file, if any).
    public mutating func discardIfBlank(_ id: Note.ID) -> [DiskOp] {
        guard let n = note(id), n.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return trash(id)
    }

    /// Move a note to the Trash (recoverable in Finder).
    public mutating func trash(_ id: Note.ID) -> [DiskOp] {
        guard let l = location(of: id) else { return [] }
        let note = folders[l.folder].notes.remove(at: l.note)
        folders[l.folder].suggestedNotes.remove(id)
        guard note.isOnDisk else { return [] }
        return [.trashNote(folder: folders[l.folder].name, file: note.fileName), .saveIndex(index)]
    }

    /// Move a note to another folder, at the top unless `at` is given. `preferring`
    /// is a file name to use if it's free and still fits the note (undo).
    public mutating func move(_ id: Note.ID, to folderID: Folder.ID, at position: Int? = nil, preferring: String? = nil) -> [DiskOp] {
        guard let l = location(of: id), let target = folderIndex(folderID) else { return [] }
        if l.folder == target {
            if let position { return reorder(id, to: position) }
            return []
        }
        var ops: [DiskOp] = []
        var note = folders[l.folder].notes.remove(at: l.note)
        // Once it leaves, it no longer came with a suggestion; moved back by
        // hand, it counts as filed by hand.
        folders[l.folder].suggestedNotes.remove(id)
        let from = folders[l.folder].name, to = folders[target].name
        if note.isOnDisk {
            let newName = fileName(for: note, in: target, preferring: preferring)
            ops.append(.move(from: from, to: to, file: note.fileName, newFile: newName))
            note.fileName = newName
            if note.dirty {
                ops.append(.write(folder: to, file: newName, text: note.text, modified: nil))
                note.dirty = false
            }
        }
        let p = min(max(position ?? 0, 0), folders[target].notes.count)
        folders[target].notes.insert(note, at: p)
        ops.append(.saveIndex(index))
        return ops
    }

    /// Marks notes in a folder as having arrived with a starter-folder
    /// suggestion, so they don't count as filed by hand.
    public mutating func markSuggested(_ ids: [Note.ID], in folderID: Folder.ID) -> [DiskOp] {
        guard let fi = folderIndex(folderID) else { return [] }
        let present = Set(folders[fi].notes.map(\.id))
        let marked = ids.filter(present.contains)
        guard !marked.isEmpty else { return [] }
        folders[fi].suggestedNotes.formUnion(marked)
        return [.saveIndex(index)]
    }

    /// Reorder within a folder.
    public mutating func reorder(_ id: Note.ID, to position: Int) -> [DiskOp] {
        guard let l = location(of: id) else { return [] }
        var notes = folders[l.folder].notes
        let note = notes.remove(at: l.note)
        let p = min(max(position, 0), notes.count)
        notes.insert(note, at: p)
        guard notes != folders[l.folder].notes else { return [] }
        folders[l.folder].notes = notes
        return [.saveIndex(index)]
    }

    // MARK: Folders

    /// A new user folder, placed just before Archive.
    public mutating func createFolder(named raw: String) -> (Folder.ID, [DiskOp]) {
        let name = uniqueFolderName(NoteNaming.folderName(raw))
        let used = Set(userFolders.map(\.color))
        let color = FolderColor.userChoices.first { !used.contains($0) }
            ?? FolderColor.userChoices[userFolders.count % FolderColor.userChoices.count]
        let folder = Folder(name: name, color: color)
        folders.insert(folder, at: folders.count - 1)
        return (folder.id, [.makeFolder(name), .saveIndex(index)])
    }

    public mutating func renameFolder(_ id: Folder.ID, to raw: String) -> [DiskOp] {
        guard let fi = folderIndex(id), folders[fi].kind == .user else { return [] }
        let old = folders[fi].name
        let cleaned = NoteNaming.folderName(raw)
        guard cleaned != old else { return [] }
        folders[fi].name = "" // so it doesn't collide with itself
        let name = uniqueFolderName(cleaned)
        folders[fi].name = name
        return [.renameFolder(from: old, to: name), .saveIndex(index)]
    }

    public mutating func setColor(_ id: Folder.ID, _ color: FolderColor) -> [DiskOp] {
        guard let fi = folderIndex(id), folders[fi].kind == .user, folders[fi].color != color else { return [] }
        folders[fi].color = color
        return [.saveIndex(index)]
    }

    /// Delete a user folder. Its notes go to Inbox first; nothing is lost.
    public mutating func deleteFolder(_ id: Folder.ID) -> [DiskOp] {
        guard let fi = folderIndex(id), folders[fi].kind == .user else { return [] }
        var ops: [DiskOp] = []
        let inboxID = inbox.id
        for note in folders[fi].notes.reversed() {
            ops += move(note.id, to: inboxID).filter { if case .saveIndex = $0 { false } else { true } }
        }
        let name = folders[fi].name
        folders.remove(at: fi)
        ops.append(.trashFolder(name))
        ops.append(.saveIndex(index))
        return ops
    }

    public mutating func moveFolder(_ id: Folder.ID, to position: Int) -> [DiskOp] {
        guard let fi = folderIndex(id), folders[fi].kind == .user else { return [] }
        var users = userFolders
        guard let ui = users.firstIndex(where: { $0.id == id }) else { return [] }
        let f = users.remove(at: ui)
        users.insert(f, at: min(max(position, 0), users.count))
        let new = [inbox] + users + [archive]
        guard new != folders else { return [] }
        folders = new
        return [.saveIndex(index)]
    }

    // MARK: Undo

    /// What puts a note back where it is now. Take it before moving the note.
    public func placement(of id: Note.ID) -> LibraryChange? {
        guard let l = location(of: id) else { return nil }
        let f = folders[l.folder], note = f.notes[l.note]
        return .place(id, folder: f.id, position: l.note, suggested: f.suggestedNotes.contains(id), fileName: note.fileName)
    }

    /// What brings a note back after it's trashed. Nil for a note that was
    /// never saved, since there's nothing to bring back.
    public func restoration(of id: Note.ID) -> LibraryChange? {
        guard let l = location(of: id) else { return nil }
        let f = folders[l.folder], note = f.notes[l.note]
        guard note.isOnDisk else { return nil }
        return .restore(note, folder: f.id, folderName: f.name, position: l.note, suggested: f.suggestedNotes.contains(id))
    }

    /// What brings a folder back after it's deleted, empty: its notes return
    /// by their own placements.
    public func restoration(ofFolder id: Folder.ID) -> LibraryChange? {
        guard let fi = folderIndex(id), folders[fi].kind == .user else { return nil }
        let f = folders[fi]
        return .restoreFolder(Folder(id: f.id, name: f.name, color: f.color), position: fi)
    }

    /// Make one change. Returns the change that reverses it, so undo and redo
    /// are the same operation, or nil if what it needs is gone (a note or
    /// folder removed in Finder, say). Edits made since, like text, are kept.
    public mutating func apply(_ change: LibraryChange) -> (reverse: LibraryChange, ops: [DiskOp])? {
        switch change {
        case let .place(id, folder, position, suggested, fileName):
            guard let reverse = placement(of: id), let fi = folderIndex(folder) else { return nil }
            var ops = move(id, to: folder, at: position, preferring: fileName)
            if suggested { folders[fi].suggestedNotes.insert(id) } else { folders[fi].suggestedNotes.remove(id) }
            ops.append(.saveIndex(index))
            return (reverse, ops)
        case let .restore(saved, folder, folderName, position, suggested):
            guard location(of: saved.id) == nil else { return nil }
            // Its folder is gone: Inbox, so the note is never lost.
            let home = folderIndex(folder)
            let fi = home ?? folderIndex(inbox.id)!
            var note = saved
            note.fileName = fileName(for: saved, in: fi, preferring: saved.fileName)
            folders[fi].notes.insert(note, at: min(max(position, 0), folders[fi].notes.count))
            if suggested && home != nil { folders[fi].suggestedNotes.insert(note.id) }
            return (.trash(note.id), [
                .restoreNote(trashedFolder: folderName, trashedFile: saved.fileName, folder: folders[fi].name, file: note.fileName, text: saved.text, modified: saved.modified),
                .saveIndex(index),
            ])
        case let .trash(id):
            guard location(of: id) != nil else { return nil }
            var ops = persist(id)
            guard let reverse = restoration(of: id) else { return nil }
            ops += trash(id)
            return (reverse, ops)
        case let .removeFolder(id):
            guard let reverse = restoration(ofFolder: id) else { return nil }
            return (reverse, deleteFolder(id))
        case let .restoreFolder(folder, position):
            guard folderIndex(folder.id) == nil else { return nil }
            var restored = folder
            restored.name = uniqueFolderName(folder.name)
            folders.insert(restored, at: min(max(position, 1), folders.count - 1))
            return (.removeFolder(folder.id), [.makeFolder(restored.name), .saveIndex(index)])
        }
    }

    // MARK: Import

    /// Add copies of Apple Stickies notes to the top of Inbox, skipping ones
    /// already imported. Returns how many were added.
    public mutating func addImported(_ stickies: [ImportedSticky]) -> (added: Int, ops: [DiskOp]) {
        guard let fi = folderIndex(inbox.id) else { return (0, []) }
        var ops: [DiskOp] = []
        var added = 0
        for s in stickies.sorted(by: { $0.modified > $1.modified }).reversed() where !importedStickies.contains(s.id) {
            importedStickies.insert(s.id)
            guard !s.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let name = NoteNaming.uniqueFileName(
                base: NoteNaming.baseName(for: s.text),
                taken: Set(folders[fi].notes.map(\.fileName)))
            folders[fi].notes.insert(Note(fileName: name, text: s.text, modified: s.modified), at: 0)
            ops.append(.write(folder: Library.inboxName, file: name, text: s.text, modified: s.modified))
            added += 1
        }
        ops.append(.saveIndex(index))
        return (added, ops)
    }

    // MARK: Reload

    /// Take a fresh read of the disk, keep IDs stable (so the UI doesn't
    /// flicker) and keep any text not yet written.
    public func merged(withDisk disk: Library) -> Library {
        var out = disk
        for fi in out.folders.indices {
            let name = out.folders[fi].name
            guard let old = folder(named: name) else { continue }
            let oldNotes = Dictionary(old.notes.filter(\.isOnDisk).map { ($0.fileName.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
            let notes = out.folders[fi].notes.map { n -> Note in
                guard let o = oldNotes[n.fileName.lowercased()] else { return n }
                return o.dirty ? o : Note(id: o.id, fileName: n.fileName, text: n.text, modified: n.modified)
            }
            // Suggested notes by file name, since the disk copy has fresh IDs.
            let suggestedFiles = Set(out.folders[fi].notes.filter { out.folders[fi].suggestedNotes.contains($0.id) }.map { $0.fileName.lowercased() })
            let suggested = Set(notes.filter { suggestedFiles.contains($0.fileName.lowercased()) }.map(\.id))
            out.folders[fi] = Folder(id: old.id, name: name, color: out.folders[fi].color, notes: notes, suggestedNotes: suggested)
            // Unsaved new notes stay where they were.
            for (i, n) in old.notes.enumerated() where !n.isOnDisk {
                out.folders[fi].notes.insert(n, at: min(i, out.folders[fi].notes.count))
            }
        }
        return out
    }

    // MARK: Helpers

    /// A free file name for a note arriving in a folder: `preferring` if it's
    /// free and still fits the note, else the note's own base made unique.
    private func fileName(for note: Note, in folder: Int, preferring: String?) -> String {
        let taken = Set(folders[folder].notes.map(\.fileName))
        if let preferring, NoteNaming.base(ofFileName: preferring) == NoteNaming.base(ofFileName: note.fileName),
           !taken.contains(where: { $0.lowercased() == preferring.lowercased() }) {
            return preferring
        }
        return NoteNaming.uniqueFileName(base: NoteNaming.base(ofFileName: note.fileName), taken: taken)
    }

    private func takenNames(in folder: Int, except id: Note.ID) -> Set<String> {
        Set(folders[folder].notes.filter { $0.id != id && $0.isOnDisk }.map(\.fileName))
    }

    private func index(updating l: (folder: Int, note: Int), with note: Note) -> LibraryIndex {
        var copy = self
        copy.folders[l.folder].notes[l.note] = note
        return copy.index
    }

    private func uniqueFolderName(_ base: String) -> String {
        let taken = Set(folders.map { $0.name.lowercased() })
        var name = base, n = 2
        while taken.contains(name.lowercased()) || name.hasPrefix(".") {
            name = "\(base) \(n)"
            n += 1
        }
        return name
    }

    /// Guarantee Inbox first and Archive last.
    private mutating func normalize() {
        if !folders.contains(where: { $0.kind == .inbox }) { folders.insert(Folder(name: Library.inboxName, color: .paper), at: 0) }
        if !folders.contains(where: { $0.kind == .archive }) { folders.append(Folder(name: Library.archiveName, color: .stone)) }
        let inbox = folders.first { $0.kind == .inbox }!
        let archive = folders.first { $0.kind == .archive }!
        folders = [inbox] + folders.filter { $0.kind == .user } + [archive]
    }
}
