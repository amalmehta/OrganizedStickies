import Foundation
import os

/// Runs `DiskOp`s one at a time, in order, off the main thread.
public actor NoteDisk {
    public struct Failure: Error, Sendable, CustomStringConvertible {
        public let op: DiskOp
        public let message: String
        public var description: String { message }
    }

    public let root: URL
    private let trash: @Sendable (URL) throws -> Void
    private let log = Logger(subsystem: "com.amalmehta.OrganizedStickies", category: "disk")

    /// `trash` defaults to the Finder Trash; tests pass something local.
    public init(root: URL, trash: (@Sendable (URL) throws -> Void)? = nil) {
        self.root = root
        self.trash = trash ?? { url in try FileManager.default.trashItem(at: url, resultingItemURL: nil) }
    }

    /// Returns the ops that failed; the rest still ran.
    @discardableResult
    public func run(_ ops: [DiskOp]) -> [Failure] {
        var failures: [Failure] = []
        for op in ops {
            do { try perform(op) } catch {
                log.error("disk op failed: \(String(describing: op), privacy: .public) — \(error.localizedDescription, privacy: .public)")
                failures.append(Failure(op: op, message: error.localizedDescription))
            }
        }
        return failures
    }

    private func url(_ folder: String, _ file: String? = nil) -> URL {
        let dir = root.appendingPathComponent(folder, isDirectory: true)
        return file.map { dir.appendingPathComponent($0) } ?? dir
    }

    private func perform(_ op: DiskOp) throws {
        let fm = FileManager.default
        switch op {
        case let .write(folder, file, text, modified):
            try fm.createDirectory(at: url(folder), withIntermediateDirectories: true)
            let target = url(folder, file)
            try Data(text.utf8).write(to: target, options: .atomic)
            if let modified { try fm.setAttributes([.modificationDate: modified], ofItemAtPath: target.path) }
        case let .rename(folder, from, to):
            guard from != to else { return }
            try moveItem(url(folder, from), url(folder, to))
        case let .move(from, to, file, newFile):
            try fm.createDirectory(at: url(to), withIntermediateDirectories: true)
            try moveItem(url(from, file), url(to, newFile))
        case let .trashNote(folder, file):
            let u = url(folder, file)
            if fm.fileExists(atPath: u.path) { try trash(u) }
        case let .makeFolder(name):
            try fm.createDirectory(at: url(name), withIntermediateDirectories: true)
        case let .renameFolder(from, to):
            try moveItem(url(from), url(to))
        case let .trashFolder(name):
            let u = url(name)
            if fm.fileExists(atPath: u.path) { try trash(u) }
        case let .saveIndex(index):
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(index).write(to: root.appendingPathComponent(LibraryIndex.fileName), options: .atomic)
        }
    }

    /// Move that tolerates case-only renames ("plan.md" → "Plan.md") on
    /// case-insensitive volumes.
    private func moveItem(_ a: URL, _ b: URL) throws {
        let fm = FileManager.default
        if a.path.lowercased() == b.path.lowercased() && a.path != b.path {
            let tmp = a.deletingLastPathComponent().appendingPathComponent(".rename-\(UUID().uuidString)")
            try fm.moveItem(at: a, to: tmp)
            try fm.moveItem(at: tmp, to: b)
        } else {
            try fm.moveItem(at: a, to: b)
        }
    }
}
