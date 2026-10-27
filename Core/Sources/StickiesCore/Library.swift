import Foundation

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
                .init(name: f.name, color: f.color, order: f.notes.compactMap { $0.isOnDisk ? $0.fileName : nil })
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
        guard note.isOnDisk else { return [] }
        return [.trashNote(folder: folders[l.folder].name, file: note.fileName), .saveIndex(index)]
    }

    /// Move a note to another folder, at the top unless `at` is given.
    public mutating func move(_ id: Note.ID, to folderID: Folder.ID, at position: Int? = nil) -> [DiskOp] {
        guard let l = location(of: id), let target = folderIndex(folderID) else { return [] }
        if l.folder == target {
            if let position { return reorder(id, to: position) }
            return []
        }
        var ops: [DiskOp] = []
        var note = folders[l.folder].notes.remove(at: l.note)
        let from = folders[l.folder].name, to = folders[target].name
        if note.isOnDisk {
            let newName = NoteNaming.uniqueFileName(
                base: NoteNaming.base(ofFileName: note.fileName),
                taken: Set(folders[target].notes.map(\.fileName)))
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
            out.folders[fi] = Folder(id: old.id, name: name, color: out.folders[fi].color, notes: notes)
            // Unsaved new notes stay where they were.
            for (i, n) in old.notes.enumerated() where !n.isOnDisk {
                out.folders[fi].notes.insert(n, at: min(i, out.folders[fi].notes.count))
            }
        }
        return out
    }

    // MARK: Helpers

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
