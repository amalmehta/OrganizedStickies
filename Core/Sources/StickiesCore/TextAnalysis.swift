import Foundation
import NaturalLanguage

/// Words for matching: lowercased, reduced to their dictionary form
/// ("runs" → "run"), with common filler words removed.
public enum TextAnalysis {
    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    public static func terms(_ text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
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
        a.weights.keys.filter { b.weights[$0] != nil }
            .sorted { a.weights[$0]! * b.weights[$0]! > a.weights[$1]! * b.weights[$1]! }
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
