import Foundation

/// "Stale" = untouched for at least `days` days and not already archived.
public enum Staleness {
    public static let defaultDays = 14
    public static let allowedDays = 3...90

    /// Whole days between the last edit and now, counted by calendar date.
    public static func daysUntouched(_ modified: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: modified), b = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    public static func isStale(_ note: Note, in kind: FolderKind, days: Int, now: Date = .now) -> Bool {
        guard kind != .archive, note.isOnDisk, !note.text.isEmpty else { return false }
        return daysUntouched(note.modified, now: now) >= days
    }

    /// "today", "yesterday", "5 days ago", "3 weeks ago", "4 months ago".
    public static func ageLabel(_ modified: Date, now: Date = .now) -> String {
        let d = daysUntouched(modified, now: now)
        switch d {
        case 0: return "today"
        case 1: return "yesterday"
        case 2..<14: return "\(d) days ago"
        case 14..<60: return "\(d / 7) weeks ago"
        case 60..<730: return "\(d / 30) months ago"
        default: return "\(d / 365) years ago"
        }
    }
}
