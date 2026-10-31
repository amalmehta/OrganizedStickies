import AppKit

public struct ImportedSticky: Sendable, Equatable {
    /// The Apple Stickies package name (a UUID), used to avoid duplicates.
    public let id: String
    public let text: String
    public let modified: Date
}

/// Copies notes out of Apple Stickies as plain text. Never writes there.
public enum StickiesImporter {
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.apple.Stickies/Data/Library/Stickies", isDirectory: true)
    }

    public enum ImportError: LocalizedError, Equatable {
        case notFound
        /// macOS refused. Apple Stickies' notes are another app's data, which it asks about once.
        case notAllowed
        case unreadable(String)
        public var errorDescription: String? {
            switch self {
            case .notFound: "Apple Stickies' notes weren't found on this Mac."
            case .notAllowed: "macOS didn't let this app read Apple Stickies' notes, so nothing was copied."
            case let .unreadable(reason): "Couldn't read Apple Stickies' notes: \(reason)"
            }
        }
    }

    public struct Reading: Sendable, Equatable {
        public let notes: [ImportedSticky]
        /// Notes that exist but couldn't be opened.
        public let unreadable: Int
    }

    public static func read(from dir: URL = defaultDirectory) throws -> Reading {
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        } catch {
            throw classify(error)
        }
        let packages = items.filter { $0.pathExtension == "rtfd" }
        let notes = packages.compactMap(readOne).sorted { $0.modified > $1.modified }
        if notes.isEmpty && !packages.isEmpty {
            throw ImportError.unreadable("none of its \(packages.count) notes could be opened.")
        }
        return Reading(notes: notes, unreadable: packages.count - notes.count)
    }

    static func classify(_ error: Error) -> ImportError {
        let error = error as NSError
        let posix = (error.userInfo[NSUnderlyingErrorKey] as? NSError).flatMap { $0.domain == NSPOSIXErrorDomain ? Int32($0.code) : nil }
        if error.code == NSFileReadNoSuchFileError || posix == ENOENT || posix == ENOTDIR { return .notFound }
        if error.code == NSFileReadNoPermissionError || posix == EPERM || posix == EACCES { return .notAllowed }
        return .unreadable(error.localizedDescription)
    }

    /// What to say after an import.
    public static func summary(read: Reading, added: Int) -> String {
        let total = read.notes.count
        if total == 0 { return "Apple Stickies has no notes to copy." }
        let trouble = read.unreadable == 0 ? "" : " \(read.unreadable) couldn't be opened."
        if added == 0 { return "Nothing new to copy: the \(total) Apple Stickies notes are already here, or blank.\(trouble)" }
        let skipped = total - added
        return "Copied \(added) \(added == 1 ? "note" : "notes") into Inbox"
            + (skipped > 0 ? " (\(skipped) blank or already here)." : ".")
            + trouble + " Apple Stickies wasn't changed."
    }

    static func readOne(_ package: URL) -> ImportedSticky? {
        let rtf = package.appendingPathComponent("TXT.rtf")
        let source = FileManager.default.fileExists(atPath: rtf.path) ? rtf : package
        let docType: NSAttributedString.DocumentType = source == rtf ? .rtf : .rtfd
        guard let attr = try? NSAttributedString(url: source, options: [.documentType: docType], documentAttributes: nil) else { return nil }
        // Attachments (images) show up as U+FFFC; plain-text notes drop them.
        let text = attr.string.replacingOccurrences(of: "\u{FFFC}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let modified = (try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .now
        return ImportedSticky(id: package.deletingPathExtension().lastPathComponent, text: text, modified: modified)
    }
}
