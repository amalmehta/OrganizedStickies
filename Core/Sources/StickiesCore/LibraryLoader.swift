import Foundation

/// Reads the notes root into a `Library`. Folders are directories, notes are
/// `.md`/`.txt` files. Unknown notes (added in Finder) go first, newest first.
public enum LibraryLoader {
    public static var defaultRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Organized Stickies", isDirectory: true)
    }

    public static func load(root: URL, fileManager fm: FileManager = .default) throws -> Library {
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        for name in [Library.inboxName, Library.archiveName] {
            try fm.createDirectory(at: root.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
        }
        let index = readIndex(root: root)
        let entries = Dictionary(index?.folders.map { ($0.name, $0) } ?? [], uniquingKeysWith: { a, _ in a })

        let dirs = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }

        var folders: [Folder] = []
        for dir in dirs {
            let name = dir.lastPathComponent
            let notes = try loadNotes(in: dir, order: entries[name]?.order ?? [], fm: fm)
            let defaultColor: FolderColor = name == Library.inboxName ? .paper : name == Library.archiveName ? .stone : .butter
            let suggestedFiles = Set(entries[name]?.suggested ?? [])
            folders.append(Folder(name: name, color: entries[name]?.color ?? defaultColor, notes: notes,
                                  suggestedNotes: Set(notes.filter { suggestedFiles.contains($0.fileName) }.map(\.id))))
        }

        // Folder order: as in the index, then unknown ones alphabetically.
        let known = index?.folders.map(\.name) ?? []
        folders.sort { a, b in
            let ia = known.firstIndex(of: a.name), ib = known.firstIndex(of: b.name)
            switch (ia, ib) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }
        // Folders without a saved color get distinct ones.
        var used = Set(folders.filter { entries[$0.name] != nil && $0.kind == .user }.map(\.color))
        for i in folders.indices where folders[i].kind == .user && entries[folders[i].name] == nil {
            let c = FolderColor.userChoices.first { !used.contains($0) } ?? .butter
            folders[i].color = c
            used.insert(c)
        }
        return Library(folders: folders, importedStickies: Set(index?.importedStickies ?? []))
    }

    static func loadNotes(in dir: URL, order: [String], fm: FileManager) throws -> [Note] {
        let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles])
            .filter { NoteNaming.readableExtensions.contains($0.pathExtension.lowercased()) }
        var notes: [Note] = []
        for url in files {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            let text = readText(url)
            notes.append(Note(fileName: url.lastPathComponent, text: text, modified: values?.contentModificationDate ?? .distantPast))
        }
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        notes.sort { a, b in
            switch (rank[a.fileName], rank[b.fileName]) {
            case let (x?, y?): return x < y
            case (nil, _?): return true
            case (_?, nil): return false
            default: return a.modified > b.modified
            }
        }
        return notes
    }

    static func readText(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }

    public static func readIndex(root: URL) -> LibraryIndex? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(LibraryIndex.fileName)) else { return nil }
        return try? JSONDecoder().decode(LibraryIndex.self, from: data)
    }
}
