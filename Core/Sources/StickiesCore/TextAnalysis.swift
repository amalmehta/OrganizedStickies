import Foundation
import NaturalLanguage

/// Words for matching: lowercased, reduced to their dictionary form
/// ("runs" → "run"), with common filler words removed.
public enum TextAnalysis {
    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Words for many texts at once. Remembered by text, so a re-sort after
    /// one note changes only analyzes that note. One at a time on purpose:
    /// spreading this over cores needs a tagger per core, and making taggers
    /// costs far more than the tagging (measured: 2.1 s vs 0.18 s for 200 notes).
    public static func terms(for texts: [String]) -> [[String]] {
        var out = [[String]?](repeating: nil, count: texts.count)
        var todo: [Int] = []
        cache.lock.lock()
        for (i, t) in texts.enumerated() {
            if let hit = cache.terms[t] { out[i] = hit } else { todo.append(i) }
        }
        cache.lock.unlock()
        if !todo.isEmpty {
            let results = todo.map { terms(texts[$0]) }
            cache.lock.lock()
            for (j, i) in todo.enumerated() {
                out[i] = results[j]
                cache.terms[texts[i]] = results[j]
            }
            cache.lock.unlock()
        }
        return out.map { $0 ?? [] }
    }

    public static func terms(_ text: String) -> [String] {
        // Making a tagger costs about 10 ms, tagging a note well under 1 ms,
        // so taggers are reused (one per thread at a time).
        let tagger = taggers.borrow()
        defer { taggers.giveBack(tagger) }
        tagger.string = text
        var out: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma,
                             options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, range in
            let word = String(text[range]).lowercased()
            let lemma = tag?.rawValue.lowercased() ?? word
            let t = lemma.isEmpty ? word : lemma
            if t.count >= 2, t.contains(where: \.isLetter), !stopwords.contains(t), !stopwords.contains(word) {
                out.append(t)
            }
            return true
        }
        return out
    }

    /// Terms that are nouns somewhere in these texts, for naming a folder
    /// after a thing ("Friction") rather than a word like "whether".
    public static func nounTerms(_ texts: [String]) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        var out: Set<String> = []
        for text in texts {
            tagger.string = text
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                                 options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, range in
                guard tag == .noun || tag == .personalName || tag == .placeName || tag == .organizationName else { return true }
                let word = String(text[range]).lowercased()
                let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue.lowercased() ?? ""
                out.insert(word)
                if !lemma.isEmpty { out.insert(lemma) }
                return true
            }
        }
        return out
    }

    private static let taggers = TaggerPool()
    private static let cache = TermsCache()

    static let stopwords: Set<String> = [
        "a", "about", "above", "after", "again", "against", "all", "also", "am", "an", "and", "any", "are", "as", "at",
        "be", "because", "been", "before", "being", "below", "between", "both", "but", "by", "can", "could", "did", "do",
        "does", "doing", "down", "during", "each", "few", "for", "from", "further", "get", "got", "had", "has", "have",
        "having", "he", "her", "here", "hers", "him", "his", "how", "if", "in", "into", "is", "it", "its", "itself",
        "just", "let", "like", "me", "more", "most", "my", "need", "no", "nor", "not", "now", "of", "off", "on", "once",
        "one", "only", "or", "other", "our", "out", "over", "own", "re", "same", "she", "should", "so", "some", "still",
        "such", "than", "that", "the", "their", "them", "then", "there", "these", "they", "this", "those", "through",
        "to", "too", "under", "until", "up", "use", "very", "via", "was", "we", "were", "what", "when", "where", "which",
        "while", "who", "why", "will", "with", "would", "you", "your", "yes", "ok", "maybe", "try", "thing", "things",
        "make", "go", "see", "look", "check", "note", "todo", "tbd", "etc", "vs", "ll", "ve", "don", "isn", "doesn",
        "el", "la", "de", "en", "le", "les", "des", "et", "un", "une", "los", "las", "que", "por", "para", "con",
    ]
}

/// NLTagger isn't safe to share between threads, so each caller borrows one.
private final class TaggerPool: @unchecked Sendable {
    private let lock = NSLock()
    private var free: [NLTagger] = []

    func borrow() -> NLTagger {
        lock.lock()
        defer { lock.unlock() }
        return free.popLast() ?? NLTagger(tagSchemes: [.lemma])
    }

    func giveBack(_ tagger: NLTagger) {
        lock.lock()
        free.append(tagger)
        lock.unlock()
    }
}

private final class TermsCache: @unchecked Sendable {
    let lock = NSLock()
    var terms: [String: [String]] = [:]
}

/// A sparse word vector with TF-IDF weights. TF-IDF = term frequency ×
/// inverse document frequency: a word counts more when it's frequent in this
/// text and rare across all notes.
struct TermVector {
    var weights: [String: Double]

    static func cosine(_ a: TermVector, _ b: TermVector) -> Double {
        let (small, large) = a.weights.count < b.weights.count ? (a, b) : (b, a)
        var dot = 0.0
        for (t, w) in small.weights { if let v = large.weights[t] { dot += w * v } }
        let na = a.norm, nb = b.norm
        return na == 0 || nb == 0 ? 0 : dot / (na * nb)
    }

    var norm: Double { weights.values.reduce(0) { $0 + $1 * $1 }.squareRoot() }

    /// Shared terms, strongest first.
    static func shared(_ a: TermVector, _ b: TermVector) -> [String] {
        // Ties break alphabetically, so a reason reads the same every sort.
        a.weights.keys.filter { b.weights[$0] != nil }
            .map { ($0, a.weights[$0]! * b.weights[$0]!) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .map(\.0)
    }
}

struct IDF {
    let values: [String: Double]
    let unseen: Double

    init(documents: [[String]]) {
        var df: [String: Int] = [:]
        for doc in documents { for t in Set(doc) { df[t, default: 0] += 1 } }
        let n = Double(documents.count)
        values = df.mapValues { log((n + 1) / (Double($0) + 1)) + 1 }
        unseen = log(n + 1) + 1
    }

    func vector(_ terms: [String], weight: Double = 1) -> TermVector {
        var tf: [String: Double] = [:]
        for t in terms { tf[t, default: 0] += 1 }
        return TermVector(weights: tf.reduce(into: [:]) { out, kv in
            out[kv.key] = weight * (1 + log(kv.value)) * (values[kv.key] ?? unseen)
        })
    }
}
