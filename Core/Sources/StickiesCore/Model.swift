import Foundation

/// The muted "paper" palette. Inbox uses `paper`, Archive uses `stone`;
/// user folders pick from the rest. Related hues sit next to each other.
public enum FolderColor: String, Codable, CaseIterable, Sendable {
    case paper, butter, sand, clay, sage, mist, lilac, stone

    /// Colors a user folder can take, in the order new folders get them.
    public static let userChoices: [FolderColor] = [.butter, .mist, .sage, .clay, .lilac, .sand]

    public var displayName: String {
        switch self {
        case .paper: "Paper"
        case .butter: "Butter"
        case .sand: "Sand"
        case .clay: "Clay"
        case .sage: "Sage"
        case .mist: "Mist"
        case .lilac: "Lilac"
        case .stone: "Stone"
        }
    }
}

public enum FolderKind: Sendable, Equatable {
    case inbox, archive, user
}

public struct Note: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// File name on disk, with extension. Empty until the note is first saved.
    public var fileName: String
    public var text: String
    /// Last edit. For notes on disk this is the file's modification date.
    public var modified: Date
    /// Text changed in memory but not yet written.
    public var dirty: Bool

    public init(id: UUID = UUID(), fileName: String, text: String, modified: Date, dirty: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.text = text
        self.modified = modified
        self.dirty = dirty
    }

    public var isOnDisk: Bool { !fileName.isEmpty }
    public var title: String { NoteNaming.title(from: text) }
    /// Everything after the title line, for the card preview.
    public var body: String { NoteNaming.body(from: text) }
    public var wordCount: Int { TextAnalysis.wordCount(text) }
}

public struct Folder: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var color: FolderColor
    public var notes: [Note]
    /// Notes that arrived with a starter-folder suggestion rather than being
    /// filed by hand. They say less about what the folder is for.
    public var suggestedNotes: Set<Note.ID>

    public init(id: UUID = UUID(), name: String, color: FolderColor, notes: [Note] = [], suggestedNotes: Set<Note.ID> = []) {
        self.id = id
        self.name = name
        self.color = color
        self.notes = notes
        self.suggestedNotes = suggestedNotes
    }

    /// Notes you filed here yourself (by drag, menu, or accepting a suggestion).
    public var filedByHand: Int { notes.count - notes.filter { suggestedNotes.contains($0.id) }.count }

    public var kind: FolderKind {
        switch name {
        case Library.inboxName: .inbox
        case Library.archiveName: .archive
        default: .user
        }
    }
}

/// One step that makes the disk match the in-memory `Library`.
public enum DiskOp: Sendable, Equatable {
    /// Write text atomically. `modified` sets the file date (used by import); nil means now.
    case write(folder: String, file: String, text: String, modified: Date?)
    case rename(folder: String, from: String, to: String)
    case move(from: String, to: String, file: String, newFile: String)
    case trashNote(folder: String, file: String)
    case makeFolder(String)
    case renameFolder(from: String, to: String)
    case trashFolder(String)
    case saveIndex(LibraryIndex)
}

/// `.organizedstickies.json` at the root: folder order, colors, note order.
/// Safe to delete — the loader falls back to newest first.
public struct LibraryIndex: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var name: String
        public var color: FolderColor
        public var order: [String]
        /// File names of notes that arrived with a starter-folder suggestion.
        /// Left out when there are none, so older index files read the same.
        public var suggested: [String]? = nil
    }
    public var version: Int = 1
    public var folders: [Entry]
    /// Apple Stickies note IDs already copied in, so import never duplicates.
    public var importedStickies: [String]

    public static let fileName = ".organizedstickies.json"
}
