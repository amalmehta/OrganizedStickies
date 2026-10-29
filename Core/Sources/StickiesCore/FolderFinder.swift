import Foundation
import NaturalLanguage

/// Meaning from word vectors: the sum of Apple's on-device word vectors for a
/// note's words (filler words dropped), compared by direction. For telling
/// whether two notes share a topic it beats the sentence model on the sample
/// notes (see SORTER-EVAL.md), which matters when there are no folders to
/// average over.
public final class WordVectorEmbedder: SentenceEmbedder, @unchecked Sendable {
    private let lock = NSLock()
    private let model = NLEmbedding.wordEmbedding(for: .english)

    public init() {}

    public func vector(for text: String) -> [Double]? {
        guard let model else { return nil }
        let terms = TextAnalysis.terms(for: [text])[0]
        lock.lock()
        defer { lock.unlock() }
        var sum: [Double]?
        for t in terms {
            guard let v = model.vector(for: t) else { continue }
            if sum == nil { sum = [Double](repeating: 0, count: v.count) }
            for k in v.indices { sum![k] += v[k] }
        }
        return sum
    }
}

/// A folder the Inbox suggests making: notes that share words and meaning,
/// with a draft name taken from the words they share.
public struct StarterFolder: Sendable, Equatable, Identifiable {
    /// The group's first note, so the same group keeps its id between sorts.
    public let id: UUID
    public var name: String
    /// In Inbox order.
    public var noteIDs: [UUID]
    /// Strongest first; what the notes have in common.
    public var sharedTerms: [String]
}

/// Tunable numbers. Estimates fitted on the sample notes (see `SorterEval`),
/// not facts about your notes.
public struct FolderFinderConfig: Sendable, Equatable {
    /// How much word overlap counts against meaning (0…1).
    public var wordWeight: Double
    /// Two groups join while their average similarity is at least this.
    public var joinAt: Double
    /// Smallest group worth a folder. Fewer notes give the sorter too little to compare with.
    public var minNotes: Int
    /// At most this many suggestions, biggest first.
    public var maxFolders: Int

    public init(wordWeight: Double, joinAt: Double, minNotes: Int = 3, maxFolders: Int = 6) {
        self.wordWeight = wordWeight
        self.joinAt = joinAt
        self.minNotes = minNotes
        self.maxFolders = maxFolders
    }

    /// Fitted on the sample notes' tune pile; checked on the held-out pile.
    public static let standard = FolderFinderConfig(wordWeight: 0.7, joinAt: 0.1125)
}

/// Finds groups in a pile of unsorted notes, for when there are no folders
/// yet and the sorter has nothing to compare with.
///
/// Agglomerative clustering with average linkage: every note starts as its
/// own group, and the two most similar groups join, again and again, until
/// no two are similar enough. "Average linkage" means two groups' similarity
/// is the average over every pair of notes across them, so one stray look-alike
/// can't drag a whole group in.
public struct FolderFinder: Sendable {
    public let config: FolderFinderConfig
    let embedder: SentenceEmbedder?

    public init(config: FolderFinderConfig = .standard, embedder: SentenceEmbedder?) {
        self.config = config
        self.embedder = embedder
    }

    /// Suggested folders, biggest first. Names avoid `taken` (existing
    /// folders) and each other, ignoring case.
    public func propose(notes: [(id: UUID, text: String)], avoiding taken: [String] = []) -> [StarterFolder] {
        let notes = notes.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard notes.count >= config.minNotes else { return [] }
        let texts = notes.map(\.text)
        let terms = TextAnalysis.terms(for: texts)
        let idf = IDF(documents: terms)
        let sim = similarities(texts, terms: terms, idf: idf)

        var used = Set(taken.map { $0.lowercased() } + [Library.inboxName.lowercased(), Library.archiveName.lowercased()])
        var out: [StarterFolder] = []
        for group in cluster(sim).filter({ $0.count >= config.minNotes }).prefix(config.maxFolders) {
            let ranked = rankTerms(group, terms: terms, idf: idf)
            let nouns = TextAnalysis.nounTerms(group.map { texts[$0] })
            let namable = ranked.filter { !Self.notNames.contains($0) }
            guard let name = (namable.filter(nouns.contains) + namable.filter { !nouns.contains($0) }).lazy.map({ displayForm($0, in: group.map { texts[$0] }) })
                .first(where: { !used.contains($0.lowercased()) }) else { continue }
            used.insert(name.lowercased())
            out.append(StarterFolder(id: notes[group[0]].id, name: name,
                                     noteIDs: group.map { notes[$0].id }, sharedTerms: Array(ranked.prefix(3))))
        }
        return out
    }

    /// How alike every pair of these notes is (0 = nothing in common).
    public func similarities(_ texts: [String]) -> [[Double]] {
        let terms = TextAnalysis.terms(for: texts)
        return similarities(texts, terms: terms, idf: IDF(documents: terms))
    }

    private func similarities(_ texts: [String], terms: [[String]], idf: IDF) -> [[Double]] {
        let meaning = centered((embedder?.vectors(for: texts) ?? texts.map { _ in nil }).map { $0.map(unit) })
        return similarities(words: terms.map { idf.vector($0) }, meaning: meaning)
    }

    /// Meaning vectors all lean the same way, so any two notes look
    /// fairly alike. Taking away the average leaves what sets each note apart,
    /// and similarities spread out.
    func centered(_ vectors: [[Double]?]) -> [[Double]?] {
        let present = vectors.compactMap { $0 }
        guard present.count >= 2, let size = present.first?.count else { return vectors }
        var mean = [Double](repeating: 0, count: size)
        for v in present { for k in mean.indices { mean[k] += v[k] / Double(present.count) } }
        return vectors.map { $0.map { v in unit(zip(v, mean).map { $0 - $1 }) } }
    }

    /// How alike every pair of notes is: word overlap and meaning, mixed.
    /// Notes without a meaning vector (not English) compare on words alone.
    func similarities(words: [TermVector], meaning: [[Double]?]) -> [[Double]] {
        let n = words.count
        var s = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for i in 0..<n {
            for j in (i + 1)..<n {
                let w = TermVector.cosine(words[i], words[j])
                var v = w
                if let a = meaning[i], let b = meaning[j] {
                    v = config.wordWeight * w + (1 - config.wordWeight) * dot(a, b)
                }
                s[i][j] = v
                s[j][i] = v
            }
        }
        return s
    }

    /// Groups of note indexes, biggest first, each in note order.
    func cluster(_ sim: [[Double]]) -> [[Int]] {
        var s = sim
        let n = sim.count
        var groups: [[Int]?] = (0..<n).map { [$0] }
        // Each group's most similar other group, so a join doesn't rescan
        // every pair (about n² work in all, not n³).
        var best = [(j: Int, v: Double)](repeating: (-1, -.infinity), count: n)
        func rescan(_ i: Int) {
            best[i] = (-1, -.infinity)
            for k in 0..<n where k != i && groups[k] != nil && s[i][k] > best[i].v { best[i] = (k, s[i][k]) }
        }
        for i in 0..<n { rescan(i) }
        while true {
            var top = -1
            for k in 0..<n where groups[k] != nil && best[k].j >= 0 && (top < 0 || best[k].v > best[top].v) { top = k }
            guard top >= 0, best[top].v >= config.joinAt else { break }
            let (a, b) = (min(top, best[top].j), max(top, best[top].j))
            let na = Double(groups[a]!.count), nb = Double(groups[b]!.count)
            // The joined group's average similarity to every other group,
            // from the two parts' averages (Lance–Williams update).
            for k in 0..<n where groups[k] != nil && k != a && k != b {
                let v = (na * s[a][k] + nb * s[b][k]) / (na + nb)
                s[a][k] = v
                s[k][a] = v
            }
            groups[a] = (groups[a]! + groups[b]!).sorted()
            groups[b] = nil
            for k in 0..<n where groups[k] != nil {
                if k == a || best[k].j == a || best[k].j == b {
                    rescan(k)
                } else if s[k][a] > best[k].v {
                    best[k] = (a, s[k][a])
                }
            }
        }
        return groups.compactMap { $0 }.sorted { $0.count != $1.count ? $0.count > $1.count : $0[0] < $1[0] }
    }

    /// Units and time words: shared by notes on any topic, so they make poor names.
    static let notNames: Set<String> = [
        "cup", "tbsp", "tsp", "gram", "kg", "lb", "lbs", "oz", "ml", "min", "minute", "hour", "hr", "sec", "second",
        "day", "week", "month", "year", "today", "tomorrow", "yesterday", "tonight", "time", "bit", "lot", "way",
        "am", "pm", "mon", "tue", "wed", "thu", "fri", "sat", "sun",
    ]

    /// Words that mark this group: common inside it, rare across all notes.
    /// A word must appear in at least two of its notes.
    func rankTerms(_ group: [Int], terms: [[String]], idf: IDF) -> [String] {
        var df: [String: Int] = [:]
        for i in group { for t in Set(terms[i]) { df[t, default: 0] += 1 } }
        return df.filter { $0.value >= 2 }
            .map { t, n in (t, Double(n) / Double(group.count) * (idf.values[t] ?? idf.unseen)) }
            // Ties break alphabetically, so a name reads the same every sort.
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .map(\.0)
    }

    /// The word as the notes write it ("PPO", "Neuropixels"), or capitalized
    /// when they only write it in lowercase.
    func displayForm(_ term: String, in texts: [String]) -> String {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: term) + "\\b"
        var seen: [String: Int] = [:]
        for text in texts {
            var range = text.startIndex..<text.endIndex
            while let r = text.range(of: pattern, options: [.regularExpression, .caseInsensitive], range: range) {
                seen[String(text[r]), default: 0] += 1
                range = r.upperBound..<text.endIndex
            }
        }
        // Prefer a form with capitals (an acronym or a name), then the most common.
        let form = seen.max { a, b in
            let (ua, ub) = (a.key != a.key.lowercased(), b.key != b.key.lowercased())
            return ua != ub ? !ua : (a.value != b.value ? a.value < b.value : a.key > b.key)
        }?.key ?? term
        return form == form.lowercased() ? form.prefix(1).uppercased() + form.dropFirst() : form
    }
}

