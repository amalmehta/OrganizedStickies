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

    public enum ImportError: LocalizedError {
        case notFound(URL)
        case unreadable(URL, String)
        public var errorDescription: String? {
            switch self {
            case .notFound: "Apple Stickies' notes weren't found on this Mac."
            case let .unreadable(_, reason): "Couldn't read Apple Stickies' notes: \(reason)"
            }
        }
    }

    public static func read(from dir: URL = defaultDirectory) throws -> [ImportedSticky] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { throw ImportError.notFound(dir) }
        let items: [URL]
        do {
            items = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        } catch {
            throw ImportError.unreadable(dir, error.localizedDescription)
        }
        return items.filter { $0.pathExtension == "rtfd" }.compactMap(readOne).sorted { $0.modified > $1.modified }
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
