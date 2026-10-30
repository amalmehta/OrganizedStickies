import Foundation
import NaturalLanguage

/// Turns text into a meaning vector. Swappable (tests use a fake; a future
/// version could use a different model).
public protocol SentenceEmbedder: Sendable {
    func vector(for text: String) -> [Double]?
    /// Many at once; implementations may run them in parallel.
    func vectors(for texts: [String]) -> [[Double]?]
}

extension SentenceEmbedder {
    public func vectors(for texts: [String]) -> [[Double]?] { texts.map(vector) }
}

/// Apple's on-device English sentence model (512 numbers per text).
/// No network, no cost. About 15–30 ms per text, so results are cached and
/// batches run on several cores, one model instance per core.
public final class AppleSentenceEmbedder: SentenceEmbedder, @unchecked Sendable {
    private let lock = NSLock()
    private var pool: [NLEmbedding]
    private var cache: [String: [Double]] = [:]
    private let available: Bool
    static let maxChars = 800

    public init() {
        let first = NLEmbedding.sentenceEmbedding(for: .english)
        available = first != nil
        pool = first.map { [$0] } ?? []
    }

    public var isAvailable: Bool { available }

    public func vector(for text: String) -> [Double]? { vectors(for: [text])[0] }

    public func vectors(for texts: [String]) -> [[Double]?] {
        guard available else { return texts.map { _ in nil } }
        let keys = texts.map { String($0.prefix(Self.maxChars)) }
        var out = [[Double]?](repeating: nil, count: keys.count)
        var todo: [Int] = []
        lock.lock()
        for (i, k) in keys.enumerated() {
            if let v = cache[k] { out[i] = v } else { todo.append(i) }
        }
        lock.unlock()
        guard !todo.isEmpty else { return out }

        let workers = min(todo.count, max(1, ProcessInfo.processInfo.activeProcessorCount - 1), 8)
        let models = (0..<workers).map { _ in borrowModel() }
        let results = UnsafeMutableBufferPointer<[Double]?>.allocate(capacity: todo.count)
        results.initialize(repeating: nil)
        defer { results.deallocate() }
        DispatchQueue.concurrentPerform(iterations: workers) { w in
            guard let model = models[w] else { return }
            var j = w
            while j < todo.count {
                let key = keys[todo[j]]
                if Self.isEnglish(key) { results[j] = model.vector(for: key) }
                j += workers
            }
        }
        lock.lock()
        for (j, i) in todo.enumerated() {
            out[i] = results[j]
            if let v = results[j] { cache[keys[i]] = v }
        }
        for m in models.compactMap({ $0 }) { pool.append(m) }
        lock.unlock()
        return out
    }

    /// A model instance not in use by another thread.
    private func borrowModel() -> NLEmbedding? {
        lock.lock()
        defer { lock.unlock() }
        if !pool.isEmpty { return pool.removeLast() }
        return NLEmbedding.sentenceEmbedding(for: .english)
    }

    static func isEnglish(_ text: String) -> Bool {
        let r = NLLanguageRecognizer()
        r.processString(text)
        guard let (lang, p) = r.languageHypotheses(withMaximum: 1).first else { return true }
        return lang == .english || p < 0.6
    }
}

/// Tunable numbers. All are estimates fitted on the sample notes (see
/// `SorterEval`), not facts about your notes.
public struct SorterConfig: Sendable, Equatable {
    /// How much word overlap counts against meaning (0…1).
    public var wordWeight: Double
    /// How much the single closest note counts against the folder average (0…1).
    public var nearestWeight: Double
    /// Minimum score for a suggestion.
    public var threshold: Double
    /// How far the best folder must beat the runner-up.
    public var margin: Double
    /// How many times the runner-up's score the best must reach. Unlike
    /// `margin` this doesn't depend on how big scores are, which matters
    /// because word-overlap scores for short notes are small.
    public var minRatio: Double
    /// Notes with this many words or fewer need a shared word, too.
    public var shortWords: Int
    /// A folder with fewer notes than this is young: it needs a closer match.
    public var matureNotes: Int
    /// Minimum score for a suggestion into a young folder. Few notes say
    /// little about a topic, and in a first import many notes belong to
    /// topics with no folder yet, which then drift to the nearest young one.
    public var youngThreshold: Double

    public init(wordWeight: Double, nearestWeight: Double, threshold: Double, margin: Double, minRatio: Double = 1, shortWords: Int = 7,
                matureNotes: Int = 7, youngThreshold: Double = 0.32) {
        self.wordWeight = wordWeight
        self.nearestWeight = nearestWeight
        self.threshold = threshold
        self.margin = margin
        self.minRatio = minRatio
        self.shortWords = shortWords
        self.matureNotes = matureNotes
        self.youngThreshold = youngThreshold
    }

    /// Fitted on the "tune" half of SampleNotes.json; checked on the "check" half.
    /// The young-folder numbers come from simulated first imports (see `SorterEval`).
    public static let standard = SorterConfig(wordWeight: 0.7, nearestWeight: 0.75, threshold: 0.25, margin: 0, minRatio: 1.0)

    /// The minimum score for a suggestion into a folder with this many notes.
    public func threshold(forFolderOf notes: Int) -> Double {
        notes < matureNotes ? max(threshold, youngThreshold) : threshold
    }

    /// Settings' strictness slider maps to a threshold shift.
    public func shifted(by strictness: Double) -> SorterConfig {
        var c = self
        c.threshold += strictness
        c.youngThreshold += strictness
        c.minRatio = max(1, minRatio + strictness)
        return c
    }
}

public enum SortOutcome: Sendable, Equatable {
    case suggest(folder: String, score: Double, reason: String)
    case noClearMatch(reason: String)

    public var folder: String? {
        if case let .suggest(f, _, _) = self { return f }
        return nil
    }
}

/// A folder the sorter can send notes to.
public struct SortCandidate: Sendable {
    public let name: String
    public let notes: [String]
    /// How many of `notes` arrived with a starter-folder suggestion. They
    /// don't count toward the folder being grown: a suggested group can mix
    /// topics, and only notes you filed yourself show what it's for.
    public let suggestedNotes: Int

    public init(name: String, notes: [String], suggestedNotes: Int = 0) {
        self.name = name
        self.notes = notes
        self.suggestedNotes = suggestedNotes
    }
}

/// How one note compares to each folder. Expensive to compute (meaning
/// vectors), cheap to decide on, so tuning reuses it.
public struct NoteAnalysis: Sendable {
    public struct FolderMatch: Sendable {
        public let folder: String
        /// How many notes the folder holds.
        public let noteCount: Int
        /// How many of them arrived with a starter-folder suggestion.
        public let suggestedNotes: Int
        /// Notes filed by hand: what decides whether the folder is young.
        public var filedByHand: Int { noteCount - suggestedNotes }
        public let words: Double
        public let meanMeaning: Double?
        public let nearestMeaning: Double?
        public let nearestTitle: String?
        public let sharedTerms: [String]
    }
    public let wordCount: Int
    public let matches: [FolderMatch]

    /// The same analysis as if every note had been filed by hand, as before
    /// v1.2.2 (for comparing versions in SorterEval).
    public func countingEveryNoteAsFiledByHand() -> NoteAnalysis {
        NoteAnalysis(wordCount: wordCount, matches: matches.map {
            FolderMatch(folder: $0.folder, noteCount: $0.noteCount, suggestedNotes: 0, words: $0.words, meanMeaning: $0.meanMeaning,
                        nearestMeaning: $0.nearestMeaning, nearestTitle: $0.nearestTitle, sharedTerms: $0.sharedTerms)
        })
    }
}

public struct Sorter: Sendable {
    public let config: SorterConfig
    let embedder: SentenceEmbedder?

    public init(config: SorterConfig = .standard, embedder: SentenceEmbedder?) {
        self.config = config
        self.embedder = embedder
    }

    /// The first word analysis in a process takes about 2 s while macOS loads
    /// its language data; later ones take well under 1 ms a note. Call this
    /// early, in the background, so the first sort doesn't pay for it.
    public static func warmUp(_ embedder: SentenceEmbedder? = nil) {
        _ = TextAnalysis.terms("Warming up the notes sorter")
        _ = embedder?.vector(for: "Warming up the notes sorter")
    }

    public func suggest(notes: [(id: UUID, text: String)], folders: [SortCandidate]) -> [UUID: SortOutcome] {
        var out: [UUID: SortOutcome] = [:]
        suggest(notes: notes, folders: folders) { out.merge($0) { _, new in new } }
        return out
    }

    /// Same answers as `suggest`, handed over a few notes at a time in the
    /// order given, so the first cards get theirs in a fraction of a second.
    /// Stops early if the calling task is cancelled.
    public func suggest(notes: [(id: UUID, text: String)], folders: [SortCandidate], batchSize: Int = 12,
                        onBatch: ([UUID: SortOutcome]) -> Void) {
        let hasFolders = !folders.isEmpty
        analyze(notes: notes.map(\.text), folders: folders, batchSize: batchSize) { range, analyses in
            var out: [UUID: SortOutcome] = [:]
            for (n, a) in zip(notes[range], analyses) { out[n.id] = decide(a, hasFolders: hasFolders) }
            onBatch(out)
        }
    }

    public func analyze(notes: [String], folders: [SortCandidate]) -> [NoteAnalysis] {
        var out: [NoteAnalysis] = []
        analyze(notes: notes, folders: folders, batchSize: max(notes.count, 1)) { _, a in out += a }
        return out
    }

    /// The expensive part. Word weights (IDF) use every note up front, so a
    /// note's analysis is identical whichever batch it lands in.
    public func analyze(notes: [String], folders: [SortCandidate], batchSize: Int,
                        onBatch: (Range<Int>, [NoteAnalysis]) -> Void) {
        let allTerms = TextAnalysis.terms(for: notes + folders.flatMap(\.notes))
        let noteTerms = Array(allTerms.prefix(notes.count))
        var rest = allTerms.dropFirst(notes.count)
        let folderNoteTerms = folders.map { f in (0..<f.notes.count).map { _ in rest.popFirst()! } }
        let idf = IDF(documents: noteTerms + folderNoteTerms.flatMap { $0 })

        let folderVectors: [TermVector] = folders.indices.map { i in
            var v = idf.vector(TextAnalysis.terms(folders[i].name), weight: 3)
            for terms in folderNoteTerms[i] {
                for (t, w) in idf.vector(terms).weights { v.weights[t, default: 0] += w }
            }
            return v
        }

        // Meaning vectors for the folders first (every note needs them), in
        // one parallel, cached batch.
        let folderTexts = folders.flatMap { [$0.name] + $0.notes }
        var vectors = (embedder?.vectors(for: folderTexts) ?? folderTexts.map { _ in nil })[...]
        // Each folder's name plus its notes.
        let folderMeaning: [[(title: String, v: [Double])]] = folders.map { f in
            var list: [(String, [Double])] = []
            if let v = vectors.popFirst() ?? nil { list.append((f.name, unit(v))) }
            for text in f.notes {
                if let v = vectors.popFirst() ?? nil { list.append((NoteNaming.title(from: text), unit(v))) }
            }
            return list
        }
        let centroids: [[Double]?] = folderMeaning.map { list in
            guard let first = list.first else { return nil }
            var c = [Double](repeating: 0, count: first.v.count)
            for item in list { for k in c.indices { c[k] += item.v[k] } }
            return unit(c)
        }

        let size = max(1, batchSize)
        for start in stride(from: 0, to: notes.count, by: size) {
            if Task.isCancelled { return }
            let range = start..<min(start + size, notes.count)
            let texts = Array(notes[range])
            let noteVectors = embedder?.vectors(for: texts) ?? texts.map { _ in nil }
            onBatch(range, range.map { analyzeOne($0, noteVectors[$0 - start]) })
        }

        func analyzeOne(_ ni: Int, _ vector: [Double]?) -> NoteAnalysis {
            let tv = idf.vector(noteTerms[ni])
            let nv = vector.map(unit)
            let matches = folders.indices.map { fi -> NoteAnalysis.FolderMatch in
                var mean: Double?, nearest: Double?, nearestTitle: String?
                if let nv, let c = centroids[fi] {
                    mean = dot(nv, c)
                    for item in folderMeaning[fi] {
                        let s = dot(nv, item.v)
                        if s > (nearest ?? -1) { nearest = s; nearestTitle = item.title }
                    }
                }
                return .init(folder: folders[fi].name, noteCount: folders[fi].notes.count,
                             suggestedNotes: min(folders[fi].suggestedNotes, folders[fi].notes.count), words: TermVector.cosine(tv, folderVectors[fi]),
                             meanMeaning: mean, nearestMeaning: nearest, nearestTitle: nearestTitle,
                             sharedTerms: TermVector.shared(tv, folderVectors[fi]))
            }
            return NoteAnalysis(wordCount: TextAnalysis.wordCount(notes[ni]), matches: matches)
        }
    }

    public func score(_ m: NoteAnalysis.FolderMatch) -> Double {
        guard let mean = m.meanMeaning, let near = m.nearestMeaning else { return m.words }
        let meaning = (1 - config.nearestWeight) * mean + config.nearestWeight * near
        return config.wordWeight * m.words + (1 - config.wordWeight) * meaning
    }

    public func decide(_ a: NoteAnalysis, hasFolders: Bool = true) -> SortOutcome {
        guard hasFolders, !a.matches.isEmpty else {
            return .noClearMatch(reason: "Make a folder first. Sorting needs somewhere to send notes.")
        }
        let ranked = a.matches.map { ($0, score($0)) }.sorted { $0.1 > $1.1 }
        let (best, s1) = ranked[0]
        let s2 = ranked.count > 1 ? ranked[1].1 : 0
        let isShort = a.wordCount <= config.shortWords

        if isShort && best.sharedTerms.isEmpty {
            let words = a.wordCount == 1 ? "1 word" : "\(a.wordCount) words"
            return .noClearMatch(reason: "Too short to judge (\(words)), and it shares no words with any folder.")
        }
        if s1 < config.threshold {
            return .noClearMatch(reason: "Nothing here looks much like it. The closest is \(best.folder).")
        }
        if s1 < config.threshold(forFolderOf: best.filedByHand) {
            let n = best.filedByHand
            if best.suggestedNotes > 0 {
                let filed = n == 0 ? "you haven't filed any notes there yourself yet" : "you've filed only \(n == 1 ? "1 note" : "\(n) notes") there yourself"
                return .noClearMatch(reason: "Maybe \(best.folder), but \(filed), so it needs a closer match.")
            }
            return .noClearMatch(reason: "Maybe \(best.folder), but it has only \(n == 1 ? "1 note" : "\(n) notes"), so it needs a closer match.")
        }
        if s1 - s2 < config.margin || (s2 > 0 && s1 / s2 < config.minRatio) {
            return .noClearMatch(reason: "It could be \(best.folder) or \(ranked[1].0.folder). Too close to call.")
        }
        return .suggest(folder: best.folder, score: s1, reason: reason(for: best))
    }

    private func reason(for m: NoteAnalysis.FolderMatch) -> String {
        let meaning = m.nearestMeaning ?? 0
        if !m.sharedTerms.isEmpty && (m.words >= 0.15 || meaning < 0.55 || m.nearestTitle == nil) {
            let words = m.sharedTerms.prefix(3).map { "“\($0)”" }.joined(separator: ", ")
            return "Shares \(words) with notes in \(m.folder)."
        }
        if let t = m.nearestTitle, !t.isEmpty {
            return t == m.folder ? "Close in meaning to the folder's name." : "Close in meaning to “\(t)”."
        }
        return "Looks like the notes in \(m.folder)."
    }
}

func unit(_ v: [Double]) -> [Double] {
    let n = v.reduce(0) { $0 + $1 * $1 }.squareRoot()
    return n == 0 ? v : v.map { $0 / n }
}

func dot(_ a: [Double], _ b: [Double]) -> Double {
    var s = 0.0
    for i in 0..<min(a.count, b.count) { s += a[i] * b[i] }
    return s
}
