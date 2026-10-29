import Foundation

/// The bundled sample notes (`Resources/SampleNotes.json`): invented notes
/// for demo mode, tuning the sorter, and checking it on a held-out half.
public struct SampleSet: Decodable, Sendable {
    public struct SampleNote: Decodable, Sendable {
        public let text: String
        public let daysAgo: Int
    }
    public struct SampleFolder: Decodable, Sendable {
        public let name: String
        public let color: FolderColor
        public let notes: [SampleNote]
    }
    public struct InboxNote: Decodable, Sendable {
        public let text: String
        public let daysAgo: Int
        /// The folder a careful person would choose, or nil for "nowhere".
        public let expected: String?
        public let split: String

        public init(text: String, daysAgo: Int, expected: String?, split: String) {
            self.text = text
            self.daysAgo = daysAgo
            self.expected = expected
            self.split = split
        }
    }

    public let folders: [SampleFolder]
    public let inbox: [InboxNote]
    public let archive: [SampleNote]

    public static func load() throws -> SampleSet {
        guard let url = Bundle.module.url(forResource: "SampleNotes", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(SampleSet.self, from: Data(contentsOf: url))
    }

    /// The sample as a `Library` (file names assigned, nothing on disk yet).
    /// `unsorted` puts every note in Inbox with no folders, like a first import.
    public func library(now: Date = .now, unsorted: Bool = false) -> Library {
        func notes(_ items: [(String, Int)]) -> [Note] {
            var taken: Set<String> = []
            return items.map { text, days in
                let name = NoteNaming.uniqueFileName(base: NoteNaming.baseName(for: text), taken: taken)
                taken.insert(name)
                return Note(fileName: name, text: text, modified: now.addingTimeInterval(-Double(days) * 86_400))
            }
        }
        if unsorted {
            let all = inbox.map { ($0.text, $0.daysAgo) } + self.folders.flatMap { $0.notes.map { ($0.text, $0.daysAgo) } }
            return Library(folders: [Folder(name: Library.inboxName, color: .paper, notes: notes(all)),
                                     Folder(name: Library.archiveName, color: .stone, notes: notes(archive.map { ($0.text, $0.daysAgo) }))])
        }
        var folders = [Folder(name: Library.inboxName, color: .paper, notes: notes(inbox.map { ($0.text, $0.daysAgo) }))]
        folders += self.folders.map { Folder(name: $0.name, color: $0.color, notes: notes($0.notes.map { ($0.text, $0.daysAgo) })) }
        folders.append(Folder(name: Library.archiveName, color: .stone, notes: notes(archive.map { ($0.text, $0.daysAgo) })))
        return Library(folders: folders)
    }

    /// Write the sample to a notes root (demo mode, "Add sample notes").
    /// Folders that already exist get the sample notes added beside theirs.
    public func write(to root: URL, now: Date = .now, unsorted: Bool = false) throws {
        let lib = library(now: now, unsorted: unsorted)
        let fm = FileManager.default
        for folder in lib.folders {
            let dir = root.appendingPathComponent(folder.name, isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for note in folder.notes {
                let url = dir.appendingPathComponent(note.fileName)
                guard !fm.fileExists(atPath: url.path) else { continue }
                try Data(note.text.utf8).write(to: url, options: .atomic)
                try fm.setAttributes([.modificationDate: note.modified], ofItemAtPath: url.path)
            }
        }
        var index = LibraryLoader.readIndex(root: root) ?? LibraryIndex(folders: [], importedStickies: [])
        for entry in lib.index.folders where !index.folders.contains(where: { $0.name == entry.name }) {
            index.folders.append(entry)
        }
        // Keep Archive last.
        index.folders.sort { ($0.name == Library.archiveName ? 1 : 0) < ($1.name == Library.archiveName ? 1 : 0) }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(index).write(to: root.appendingPathComponent(LibraryIndex.fileName), options: .atomic)
    }
}
