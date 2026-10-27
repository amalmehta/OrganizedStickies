import Foundation

/// Titles and file names. A note's file is named after its first line,
/// the way a person would name it: "Sim-to-real checklist.md".
public enum NoteNaming {
    public static let fileExtension = "md"
    public static let readableExtensions: Set<String> = ["md", "markdown", "txt"]
    static let maxBaseLength = 60

    /// First non-empty line, without leading Markdown heading marks.
    public static func title(from text: String) -> String {
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            var t = line.trimmingCharacters(in: .whitespaces)
            while t.hasPrefix("#") { t.removeFirst() }
            t = t.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { return t }
        }
        return ""
    }

    /// Text after the title line, trimmed.
    public static func body(from text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
        if !lines.isEmpty { lines.removeFirst() }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A safe file base name (no extension) for the note's title.
    public static func baseName(for text: String) -> String {
        sanitize(title(from: text))
    }

    public static func sanitize(_ raw: String) -> String {
        var s = ""
        for ch in raw {
            if ch == "/" || ch == ":" || ch == "\\" { s.append("-") }
            else if ch.unicodeScalars.allSatisfy({ CharacterSet.controlCharacters.contains($0) }) { s.append(" ") }
            else { s.append(ch) }
        }
        s = s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        // A leading dot would hide the file in Finder.
        s = String(s.drop(while: { $0 == "." || $0 == " " }))
        if s.count > maxBaseLength {
            let cut = s.prefix(maxBaseLength)
            if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) > maxBaseLength / 2 {
                s = String(cut[..<space])
            } else {
                s = String(cut)
            }
        }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return s.isEmpty ? "Untitled" : s
    }

    /// "base.md", or "base 2.md", "base 3.md"… if taken. Case-insensitive,
    /// like the default Mac file system.
    public static func uniqueFileName(base: String, taken: Set<String>) -> String {
        let lowered = Set(taken.map { $0.lowercased() })
        var candidate = "\(base).\(fileExtension)"
        var n = 2
        while lowered.contains(candidate.lowercased()) {
            candidate = "\(base) \(n).\(fileExtension)"
            n += 1
        }
        return candidate
    }

    /// The base a file name was made from, ignoring a " 2"-style suffix,
    /// so retyping the same title doesn't rename "Plan 2.md" to "Plan 3.md".
    static func base(ofFileName name: String) -> String {
        let stem = (name as NSString).deletingPathExtension
        if let r = stem.range(of: #" \d+$"#, options: .regularExpression) {
            return String(stem[..<r.lowerBound])
        }
        return stem
    }

    /// True when a file name already fits the base ("Plan.md", "Plan 2.md"
    /// or "Week 2.md" for "Week 2"), so no rename is needed. Exact case counts,
    /// so fixing "plan" to "Plan" renames the file.
    static func fileName(_ name: String, matches base: String) -> Bool {
        let stem = (name as NSString).deletingPathExtension
        return stem == base || self.base(ofFileName: name) == base
    }

    /// A safe folder name.
    public static func folderName(_ raw: String) -> String {
        let s = sanitize(raw)
        return s == "Untitled" && raw.trimmingCharacters(in: .whitespaces).isEmpty ? "New Folder" : s
    }
}
