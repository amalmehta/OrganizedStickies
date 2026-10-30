import Foundation
import StickiesCore

// Fits the sorter's numbers on the "tune" half of the sample notes, then
// reports precision and coverage on the held-out "check" half, next to
// simpler baselines. Run: swift run sorter-eval [--write path.md]
//
// precision = suggestions that were right / suggestions shown
//             (a suggestion for a note that belongs nowhere counts as wrong)
// coverage  = notes of 8+ words with a real home that got any suggestion

struct Metrics {
    var shown = 0, correct = 0, longWithHome = 0, longCovered = 0, shortShown = 0, shortCorrect = 0, nilSuggested = 0
    var precision: Double { shown == 0 ? 1 : Double(correct) / Double(shown) }
    var coverage: Double { longWithHome == 0 ? 0 : Double(longCovered) / Double(longWithHome) }
}

let sample = try SampleSet.load()
/// v1.2's sorter: no closer match needed for young folders.
let noYoungRule: SorterConfig = { var c = SorterConfig.standard; c.youngThreshold = c.threshold; return c }()
/// v1.2.1's sorter: young folders needed 0.33 (starter notes counted as filed by hand).
let v121: SorterConfig = { var c = SorterConfig.standard; c.youngThreshold = 0.33; return c }()
let candidates = sample.folders.map { SortCandidate(name: $0.name, notes: $0.notes.map(\.text)) }
let embedder = AppleSentenceEmbedder()
let base = Sorter(embedder: embedder)
let check = sample.inbox.filter { $0.split == "check" }
// Leave-one-out on filed notes: take each note out of its folder and ask
// where it goes. Adds labelled cases to the tune set without touching "check".
var looNotes: [SampleSet.InboxNote] = []
var looA: [NoteAnalysis] = []
for (fi, folder) in sample.folders.enumerated() {
    for (ni, note) in folder.notes.enumerated() {
        var c = candidates
        var rest = folder.notes.map(\.text)
        rest.remove(at: ni)
        c[fi] = SortCandidate(name: folder.name, notes: rest)
        looNotes.append(.init(text: note.text, daysAgo: note.daysAgo, expected: folder.name, split: "loo"))
        looA += base.analyze(notes: [note.text], folders: c)
    }
}
let inboxTune = sample.inbox.filter { $0.split == "tune" }
let tune = inboxTune + looNotes
let tuneA = base.analyze(notes: inboxTune.map(\.text), folders: candidates) + looA
let checkA = base.analyze(notes: check.map(\.text), folders: candidates)

func evaluate(_ config: SorterConfig, _ notes: [SampleSet.InboxNote], _ analyses: [NoteAnalysis]) -> Metrics {
    let s = Sorter(config: config, embedder: nil)
    var m = Metrics()
    for (n, a) in zip(notes, analyses) {
        let out = s.decide(a)
        let long = a.wordCount > config.shortWords
        if long && n.expected != nil { m.longWithHome += 1 }
        guard let f = out.folder else { continue }
        m.shown += 1
        if f == n.expected { m.correct += 1; if !long { m.shortCorrect += 1 } }
        if n.expected == nil { m.nilSuggested += 1 }
        if !long { m.shortShown += 1 }
        if long && n.expected != nil { m.longCovered += 1 }
    }
    return m
}

/// Best config on `tune`: most coverage with precision >= 0.9, ties to precision.
func fit(words: [Double], nearest: [Double]) -> SorterConfig {
    var best: (SorterConfig, Metrics)?
    for w in words { for nw in nearest {
        for t in stride(from: 0.0, through: 0.6, by: 0.025) { for r in [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.75, 2.0, 2.5, 3.0] {
            let c = SorterConfig(wordWeight: w, nearestWeight: nw, threshold: t, margin: 0, minRatio: r)
            let m = evaluate(c, tune, tuneA)
            guard m.precision >= 0.9 else { continue }
            if let b = best {
                if (m.coverage, m.precision, -t) > (b.1.coverage, b.1.precision, -b.0.threshold) { best = (c, m) }
            } else { best = (c, m) }
        } }
    } }
    return best?.0 ?? .standard
}

func accuracyAlwaysGuess(_ notes: [SampleSet.InboxNote], _ analyses: [NoteAnalysis], _ config: SorterConfig) -> Double {
    let s = Sorter(config: config, embedder: nil)
    let withHome = zip(notes, analyses).filter { $0.0.expected != nil }
    let right = withHome.filter { n, a in a.matches.max { s.score($0) < s.score($1) }?.folder == n.expected }.count
    return Double(right) / Double(max(1, withHome.count))
}

let grid = stride(from: 0.0, through: 1.0, by: 0.1).map { $0 }
let nearestGrid = [0.0, 0.25, 0.5, 0.75, 1.0]
let fitted = fit(words: grid, nearest: nearestGrid)
let wordsOnly = fit(words: [1.0], nearest: [0.0])
let meaningOnly = fit(words: [0.0], nearest: nearestGrid)

func pct(_ x: Double) -> String { String(format: "%.0f%%", x * 100) }
func row(_ name: String, _ c: SorterConfig) -> String {
    let t = evaluate(c, tune, tuneA), k = evaluate(c, check, checkA)
    return "| \(name) | \(pct(t.precision)) · \(pct(t.coverage)) | \(pct(k.precision)) (\(k.correct)/\(k.shown)) | \(pct(k.coverage)) (\(k.longCovered)/\(k.longWithHome)) | \(k.shortCorrect)/\(k.shortShown) | \(k.nilSuggested) | \(pct(accuracyAlwaysGuess(check, checkA, c))) |"
}

let longCheck = zip(check, checkA).filter { $0.1.wordCount > 7 }.count
var report = """
# Sorter evaluation

Generated by `swift run sorter-eval` on \(ISO8601DateFormatter().string(from: .now).prefix(10)), from the invented notes in
`Core/Sources/StickiesCore/Resources/SampleNotes.json`: \(sample.folders.count) folders with
\(sample.folders.map(\.notes.count).reduce(0, +)) filed notes, and \(sample.inbox.count) inbox notes labelled with the folder a person
would choose (or none). The numbers were fitted on \(tune.count) "tune" cases (\(inboxTune.count) tune inbox notes plus each of the \(looNotes.count) filed notes taken out of its folder in turn) and are reported on the \(check.count) held-out
"check" notes (\(longCheck) of them have 8+ words). These are sample notes, not yours, so treat the results as
an estimate of how the sorter behaves, not a measurement on your real notes.

- **Precision**: of the suggestions shown, how many were right. A suggestion for a note that belongs nowhere counts as wrong.
- **Coverage**: of the notes with 8+ words that have a real home, how many got a suggestion.
- **Always-guess accuracy**: how often the top-scoring folder is right if you force a guess for every note with a home. This is the ceiling a threshold trades against.

| Method | Tune: precision · coverage | Check: precision | Check: coverage (8+ words) | Check: short notes right/shown | Check: suggested for "nowhere" notes | Check: always-guess accuracy |
|---|---|---|---|---|---|---|
\(row("Shipped default (`SorterConfig.standard`)", .standard))
\(row("Fitted: words + meaning", fitted))
\(row("Baseline: words only", wordsOnly))
\(row("Baseline: meaning only", meaningOnly))

Fitted numbers: word weight \(fitted.wordWeight), nearest-note weight \(fitted.nearestWeight), threshold \(String(format: "%.3f", fitted.threshold)), ratio \(fitted.minRatio).
Words only: threshold \(String(format: "%.3f", wordsOnly.threshold)), ratio \(wordsOnly.minRatio).
Meaning only: nearest-note weight \(meaningOnly.nearestWeight), threshold \(String(format: "%.3f", meaningOnly.threshold)), ratio \(meaningOnly.minRatio).

"""

// Cascade: accept every suggestion for the whole Inbox, re-sort with the
// grown folders, repeat until nothing new is suggested.
do {
    var folders = sample.folders.map { (name: $0.name, notes: $0.notes.map(\.text)) }
    var inbox = sample.inbox
    var rounds: [(shown: Int, right: Int)] = []
    let s = Sorter(config: .standard, embedder: embedder)
    while rounds.count < 5 {
        let analyses = s.analyze(notes: inbox.map(\.text), folders: folders.map { SortCandidate(name: $0.name, notes: $0.notes) })
        var keep: [SampleSet.InboxNote] = []
        var shown = 0, right = 0
        for (n, a) in zip(inbox, analyses) {
            if let f = s.decide(a).folder {
                shown += 1
                if f == n.expected { right += 1 }
                if let i = folders.firstIndex(where: { $0.name == f }) { folders[i].notes.append(n.text) }
            } else { keep.append(n) }
        }
        if shown == 0 { break }
        rounds.append((shown, right))
        inbox = keep
    }
    report += "\n## Accepting everything, round after round\n\nWhat happens if you press **Move N Suggested** on the whole sample Inbox (all \(sample.inbox.count) notes, tune and check), then again on the new suggestions that appear once the folders hold more notes:\n\n| Round | Suggested | Right |\n|---|---|---|\n"
    for (i, r) in rounds.enumerated() { report += "| \(i + 1) | \(r.shown) | \(r.right) |\n" }
    let total = rounds.reduce((0, 0)) { ($0.0 + $1.shown, $0.1 + $1.right) }
    report += "\nIn all, \(total.1) of \(total.0) moves were right (\(pct(Double(total.1) / Double(max(1, total.0))))), and \(inbox.count) notes stayed in Inbox. Later rounds lean on earlier moves, so a wrong move can pull in more. That's why every round is a click, never automatic.\n"
}

if CommandLine.arguments.contains("--details") {
    report += "\n## Check-set decisions\n\n| Words | Expected | Outcome |\n|---|---|---|\n"
    let s = Sorter(config: .standard, embedder: nil)
    for (n, a) in zip(check, checkA) {
        let o = s.decide(a)
        let outcome: String
        switch o {
        case let .suggest(f, sc, r): outcome = "→ \(f) (\(String(format: "%.2f", sc))) — \(r)"
        case let .noClearMatch(r): outcome = "no match — \(r)"
        }
        report += "| \(a.wordCount) | \(n.expected ?? "—") | \(outcome) |\n"
    }
}

// Starter folders: put labelled notes in one pile, as if just imported with
// no folders, and see whether the groups found match the folders a person chose.
//
// right   = grouped notes whose folder is their group's most common folder
//           (a group whose most common label is "nowhere" counts all wrong)
// grouped = notes with a real home that landed in some group
// found   = real folders that are some group's most common folder
struct GroupMetrics {
    var groups = 0, grouped = 0, right = 0, withHome = 0, homed = 0, found = 0, folders = 0
    var names: [(name: String, size: Int, label: String)] = []
    var purity: Double { grouped == 0 ? 1 : Double(right) / Double(grouped) }
    var coverage: Double { withHome == 0 ? 0 : Double(homed) / Double(withHome) }
}

let pileTune: [(text: String, label: String?)] =
    sample.folders.flatMap { f in f.notes.map { ($0.text, Optional(f.name)) } } + inboxTune.map { ($0.text, $0.expected) }
let pileCheck: [(text: String, label: String?)] = check.map { ($0.text, $0.expected) }
let pileAll = pileTune + pileCheck
let wordVectors = WordVectorEmbedder()

func groupEval(_ config: FolderFinderConfig, _ pile: [(text: String, label: String?)]) -> GroupMetrics {
    let ids = pile.map { _ in UUID() }
    let label = Dictionary(uniqueKeysWithValues: zip(ids, pile.map(\.label)))
    let proposals = FolderFinder(config: config, embedder: wordVectors).propose(notes: Array(zip(ids, pile.map(\.text))))
    var m = GroupMetrics()
    m.groups = proposals.count
    m.withHome = pile.filter { $0.label != nil }.count
    let counts = Dictionary(grouping: pile.compactMap(\.label), by: { $0 }).mapValues(\.count)
    m.folders = counts.filter { $0.value >= config.minNotes }.count
    var found: Set<String> = []
    for p in proposals {
        let labels = p.noteIDs.map { label[$0] ?? nil }
        let tally = Dictionary(grouping: labels, by: { $0 ?? "—" }).mapValues(\.count)
        let top = tally.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }!.key
        m.grouped += p.noteIDs.count
        m.homed += labels.filter { $0 != nil }.count
        if top != "—" {
            m.right += tally[top]!
            found.insert(top)
        }
        m.names.append((p.name, p.noteIDs.count, top))
    }
    m.found = found.count
    return m
}

// Most real folders found with 90%+ of grouped notes right (the same bar as
// suggestions), then most notes grouped.
var bestGroup: (FolderFinderConfig, GroupMetrics)?
for w in stride(from: 0.0, through: 1.0, by: 0.1) {
    for j in stride(from: 0.0, through: 0.5, by: 0.0125) {
        let c = FolderFinderConfig(wordWeight: w, joinAt: j)
        let m = groupEval(c, pileTune)
        guard m.purity >= 0.9 else { continue }
        if let b = bestGroup {
            if (m.found, m.coverage, m.purity) > (b.1.found, b.1.coverage, b.1.purity) { bestGroup = (c, m) }
        } else { bestGroup = (c, m) }
    }
}
do {
    let fittedGroup = bestGroup?.0 ?? .standard
    func groupRow(_ name: String, _ c: FolderFinderConfig, _ pile: [(text: String, label: String?)]) -> String {
        let m = groupEval(c, pile)
        return "| \(name) | \(pile.count) | \(m.groups) | \(m.found) of \(m.folders) | \(pct(m.purity)) (\(m.right)/\(m.grouped)) | \(pct(m.coverage)) (\(m.homed)/\(m.withHome)) |"
    }
    report += """

    ## Starter folders

    With no folders yet, the app offers groups it finds in the Inbox as folders to make. Here every labelled note goes into one pile, as if just imported, and the groups found are compared with the folders a person chose.

    - **Right**: of the notes put in a group, how many share the folder most common in their group. A group made mostly of notes that belong nowhere counts as all wrong.
    - **Grouped**: of the notes with a real home, how many landed in some group. The rest stay in Inbox.
    - **Folders found**: real folders (with at least \(fittedGroup.minNotes) notes in the pile) that are some group's most common folder.

    | Settings | Notes | Groups | Folders found | Right | Grouped |
    |---|---|---|---|---|---|
    \(groupRow("Shipped default, tune pile", .standard, pileTune))
    \(groupRow("Shipped default, held-out check pile", .standard, pileCheck))
    \(groupRow("Shipped default, everything at once", .standard, pileAll))
    \(groupRow("Fitted on tune pile, tune pile", fittedGroup, pileTune))
    \(groupRow("Fitted on tune pile, held-out check pile", fittedGroup, pileCheck))
    \(groupRow("Words only, check pile", FolderFinderConfig(wordWeight: 1, joinAt: fittedGroup.joinAt), pileCheck))

    Fitted numbers: word weight \(String(format: "%.1f", fittedGroup.wordWeight)), join at \(String(format: "%.3f", fittedGroup.joinAt)), at least \(fittedGroup.minNotes) notes a group, at most \(fittedGroup.maxFolders) groups. The check pile is \(pileCheck.count) notes, about the size of a first import, so a single note moves its numbers by several points.

    Groups found in the held-out check pile (name, notes, most common real folder):

    """
    for g in groupEval(fittedGroup, pileCheck).names { report += "- \(g.name): \(g.size) notes, mostly \(g.label)\n" }
    report += "\nGroups found with everything at once:\n\n"
    for g in groupEval(fittedGroup, pileAll).names { report += "- \(g.name): \(g.size) notes, mostly \(g.label)\n" }

    // The point of starter folders: once they exist, the sorter has something
    // to compare with. Make every suggested folder, then sort what's left.
    func followOn(_ pile: [(text: String, label: String?)], renamed: Bool, config: SorterConfig = .standard, countSuggested: Bool = true) -> (left: Int, shown: Int, right: Int) {
        let ids = pile.map { _ in UUID() }
        let byID = Dictionary(uniqueKeysWithValues: zip(ids, pile))
        let groups = FolderFinder(config: .standard, embedder: wordVectors).propose(notes: Array(zip(ids, pile.map(\.text))))
        var majority: [String: String] = [:]
        for g in groups {
            let tally = Dictionary(grouping: g.noteIDs.compactMap { byID[$0]?.label }, by: { $0 }).mapValues(\.count)
            majority[g.name] = tally.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key
        }
        // Renamed: you give each group the name of what it holds, and skip a
        // second group for something you already made (its notes stay in Inbox).
        var made = groups
        if renamed {
            var seen: Set<String> = []
            made = groups.filter { g in majority[g.name].map { seen.insert($0).inserted } ?? false }
            for i in made.indices {
                let label = majority[made[i].name]!
                majority[label] = label
                made[i].name = label
            }
        }
        let grouped = Set(made.flatMap(\.noteIDs))
        let rest = ids.filter { !grouped.contains($0) }
        let folders = made.map { SortCandidate(name: $0.name, notes: $0.noteIDs.map { byID[$0]!.text }, suggestedNotes: countSuggested ? $0.noteIDs.count : 0) }
        let out = Sorter(config: config, embedder: embedder).suggest(notes: rest.map { ($0, byID[$0]!.text) }, folders: folders)
        var shown = 0, right = 0
        for (id, o) in out {
            guard let f = o.folder else { continue }
            shown += 1
            if let label = byID[id]?.label, label == majority[f] { right += 1 }
        }
        return (rest.count, shown, right)
    }
    func both(_ pile: [(text: String, label: String?)], renamed: Bool) -> String {
        let b = followOn(pile, renamed: renamed, config: noYoungRule, countSuggested: false)
        let m = followOn(pile, renamed: renamed, config: v121, countSuggested: false), a = followOn(pile, renamed: renamed)
        return "\(a.left) | \(b.right)/\(b.shown) | \(m.right)/\(m.shown) | \(a.right)/\(a.shown)"
    }
    report += """

    Then the sorter takes over. After making every suggested folder, sorting the notes still in Inbox (a suggestion is right when the note belongs with most of that folder's notes). Right/suggested in v1.2, in v1.2.1 (young folders need a closer match) and now (starter folders stay young until you file notes into them; see "Young folders" below):

    | Pile | Folder names | Left in Inbox | v1.2 | v1.2.1 | Now |
    |---|---|---|---|---|---|
    | Held-out check pile | as drafted | \(both(pileCheck, renamed: false)) |
    | Held-out check pile | renamed, no duplicates | \(both(pileCheck, renamed: true)) |
    | Everything at once | as drafted | \(both(pileAll, renamed: false)) |
    | Everything at once | renamed, no duplicates | \(both(pileAll, renamed: true)) |

    """
}

// Young folders: simulated first imports. Tuning-note imports fit the young
// threshold; held-out-note imports check it, as with the sorter itself.
// Each note left in Inbox is analyzed once and decided under each threshold.
do {
    struct Rng {
        var x: UInt64
        mutating func next() -> UInt64 {
            x &+= 0x9E3779B97F4A7C15
            var z = x
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func shuffled<T>(_ a: [T]) -> [T] {
            var a = a
            for k in stride(from: a.count - 1, to: 0, by: -1) { a.swapAt(k, Int(next() % UInt64(k + 1))) }
            return a
        }
    }
    let analyzer = Sorter(config: .standard, embedder: embedder)
    /// A note left in Inbox: its analysis, and the folder that would be right (nil = none).
    typealias Case = (a: NoteAnalysis, right: String?)
    struct Sim { var drafted: [Case] = [], renamed: [Case] = [], hand: [Case] = []; var imports = 0, handImports = 0
        var all: [Case] { drafted + renamed + hand } }

    func simulate(_ notes: [(text: String, label: String?)], size: Int, starterDraws: Int, handDraws: Int, ks: [Int], seed: UInt64) -> Sim {
        var rng = Rng(x: seed)
        var sim = Sim()
        // Starter folders: make every suggested group, as drafted or renamed.
        for _ in 0..<starterDraws {
            let pile = Array(rng.shuffled(notes).prefix(size))
            let ids = pile.map { _ in UUID() }
            let byID = Dictionary(uniqueKeysWithValues: zip(ids, pile))
            let groups = FolderFinder(config: .standard, embedder: wordVectors).propose(notes: Array(zip(ids, pile.map(\.text))))
            guard !groups.isEmpty else { continue }
            sim.imports += 1
            var majority: [String: String] = [:]
            for g in groups {
                let t = Dictionary(grouping: g.noteIDs.compactMap { byID[$0]?.label }, by: { $0 }).mapValues(\.count)
                majority[g.name] = t.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key
            }
            for renamed in [false, true] {
                var made = groups
                if renamed {
                    var seen: Set<String> = []
                    made = groups.filter { g in majority[g.name].map { seen.insert($0).inserted } ?? false }
                    for m in made.indices { made[m].name = majority[made[m].name]! }
                }
                // The right folder for a real topic: the made folder holding mostly that topic.
                var home: [String: String] = [:]
                for (g, m) in zip(renamed ? made : groups, made) where majority[g.name] != nil || renamed {
                    let label = renamed ? m.name : majority[g.name]!
                    if home[label] == nil { home[label] = m.name }
                }
                let grouped = Set(made.flatMap(\.noteIDs))
                let rest = ids.filter { !grouped.contains($0) }
                let analyses = analyzer.analyze(notes: rest.map { byID[$0]!.text },
                                                folders: made.map { SortCandidate(name: $0.name, notes: $0.noteIDs.map { byID[$0]!.text },
                                                                                  suggestedNotes: $0.noteIDs.count) })
                let cases = zip(rest, analyses).map { id, a in (a: a, right: byID[id]!.label.flatMap { home[$0] }) }
                if renamed { sim.renamed += cases } else { sim.drafted += cases }
            }
        }
        // Folders made by hand: k right notes each, right names, for some of
        // the topics in the import; the rest of the import is sorted.
        for k in ks {
            for topics in [2, 4] {
                for _ in 0..<handDraws {
                    let pile = Array(rng.shuffled(notes).prefix(size))
                    let byLabel = Dictionary(grouping: pile.indices.filter { pile[$0].label != nil }, by: { pile[$0].label! })
                    let eligible = byLabel.filter { $0.value.count > k }.keys.sorted()
                    guard eligible.count >= topics else { continue }
                    sim.handImports += 1
                    let chosen = Array(rng.shuffled(eligible).prefix(topics))
                    var filed: Set<Int> = []
                    var folders: [SortCandidate] = []
                    for l in chosen {
                        let members = Array(byLabel[l]!.prefix(k))
                        filed.formUnion(members)
                        folders.append(SortCandidate(name: l, notes: members.map { pile[$0].text }))
                    }
                    let rest = pile.indices.filter { !filed.contains($0) }
                    let analyses = analyzer.analyze(notes: rest.map { pile[$0].text }, folders: folders)
                    sim.hand += zip(rest, analyses).map { n, a in (a: a, right: pile[n].label.flatMap { chosen.contains($0) ? $0 : nil }) }
                }
            }
        }
        return sim
    }

    func tally(_ cases: [Case], _ config: SorterConfig) -> (shown: Int, right: Int) {
        let s = Sorter(config: config, embedder: nil)
        var shown = 0, right = 0
        for c in cases {
            guard let f = s.decide(c.a).folder else { continue }
            shown += 1
            if f == c.right { right += 1 }
        }
        return (shown, right)
    }
    func with(young t: Double) -> SorterConfig { var c = SorterConfig.standard; c.youngThreshold = t; return c }
    /// v1.2.1: young folders, but notes from a starter group counted as filed by hand.
    func asV121(_ cases: [Case]) -> [Case] { cases.map { (a: $0.a.countingEveryNoteAsFiledByHand(), right: $0.right) } }

    let tuneSim = simulate(pileTune, size: 25, starterDraws: 100, handDraws: 25, ks: [2, 3, 5], seed: 42)
    let checkSim = simulate(pileCheck, size: 18, starterDraws: 60, handDraws: 60, ks: [2], seed: 7)
    // Big imports make big starter groups, which can mix topics.
    let bigSim = simulate(pileTune, size: 60, starterDraws: 40, handDraws: 0, ks: [], seed: 99)

    // Fit: the lowest young threshold with 90%+ of suggestions right across
    // every tuning-note import (lower keeps more suggestions).
    var fittedYoung = 0.45
    for t in stride(from: 0.25, through: 0.45, by: 0.01) {
        let m = tally(tuneSim.all, with(young: t))
        if m.shown > 0 && Double(m.right) / Double(m.shown) >= 0.9 { fittedYoung = t; break }
    }

    func cell(_ t: (shown: Int, right: Int)) -> String {
        t.shown == 0 ? "none shown" : "\(pct(Double(t.right) / Double(t.shown))) (\(t.right)/\(t.shown))"
    }
    func row(_ name: String, _ cases: [Case]) -> String {
        "| \(name) | \(cell(tally(asV121(cases), noYoungRule))) | \(cell(tally(asV121(cases), v121))) | \(cell(tally(cases, .standard))) |"
    }
    report += """

    ## Young folders

    A folder with fewer than \(SorterConfig.standard.matureNotes) notes is young, and a suggestion into it needs a score of at least \(String(format: "%.2f", SorterConfig.standard.youngThreshold)) instead of \(String(format: "%.2f", SorterConfig.standard.threshold)). Folders of 7 or 8 notes are where the sorter has been measured above 90% (the sample's folders hold 8; leaving one note out leaves 7); folders of 2 to 5 notes were measured well below it, and 6 is untested, so it counts as young. Few notes say little about a topic, and in a first import many notes belong to topics that have no folder yet, so they drift to the nearest young one.

    Notes that arrived with a starter group don't count toward those 7: a suggested group can mix topics, and only notes you file yourself show what a folder is for. So a folder made from a starter group stays young, however big, until you've filed 7 notes into it yourself (by drag, menu, or accepting a suggestion).

    Measured on simulated first imports, with fixed seeds so the numbers repeat. Tuning imports draw 25 of the \(pileTune.count) tuning notes (big ones draw 60); held-out imports draw 18 of the \(pileCheck.count) held-out notes, which the threshold never saw. In each, either every starter folder is made, or 2 or 4 folders are made by hand with the right notes and names (2, 3 or 5 notes each on tuning notes; 2 on held-out notes, which have only 3 per topic). Then the rest of the import is sorted. Precision of those suggestions in v1.2 (no young-folder rule), v1.2.1 (young folders need a closer match, starter notes counted as filed by hand) and now:

    | Imports | v1.2 | v1.2.1 | Now |
    |---|---|---|---|
    \(row("Tuning: every starter folder, names as drafted (\(tuneSim.imports))", tuneSim.drafted))
    \(row("Tuning: every starter folder, renamed (\(tuneSim.imports))", tuneSim.renamed))
    \(row("Tuning: folders made by hand (\(tuneSim.handImports))", tuneSim.hand))
    \(row("**Tuning, all**", tuneSim.all))
    \(row("Tuning, big: every starter folder, names as drafted (\(bigSim.imports))", bigSim.drafted))
    \(row("Tuning, big: every starter folder, renamed (\(bigSim.imports))", bigSim.renamed))
    \(row("Held out: every starter folder, names as drafted (\(checkSim.imports))", checkSim.drafted))
    \(row("Held out: every starter folder, renamed (\(checkSim.imports))", checkSim.renamed))
    \(row("Held out: folders made by hand (\(checkSim.handImports))", checkSim.hand))
    \(row("**Held out, all**", checkSim.all))

    Fitted young threshold: \(String(format: "%.2f", fittedYoung)) (the lowest with 90%+ right on the tuning imports; shipped: \(String(format: "%.2f", SorterConfig.standard.youngThreshold))). Imports overlap, since they're drawn from the same few notes, so these counts overstate how much evidence there is. The cost is fewer suggestions while folders are young: the notes wait in Inbox for you to file a few more by hand.

    """
}

// Why word vectors: how well each kind of meaning vector tells two notes
// on the same topic from two on different topics, one pair at a time.
// AUC = the chance a random same-folder pair scores higher than a random
// different-folder pair (0.5 is a coin flip, 1.0 is perfect).
do {
    func auc(_ pile: [(text: String, label: String?)], _ model: SentenceEmbedder) -> Double {
        let sim = FolderFinder(config: .standard, embedder: model).similarities(pile.map(\.text))
        var same: [Double] = [], diff: [Double] = []
        for i in pile.indices { for j in (i + 1)..<pile.count {
            guard let a = pile[i].label, let b = pile[j].label else { continue }
            if a == b { same.append(sim[i][j]) } else { diff.append(sim[i][j]) }
        } }
        var wins = 0.0
        for x in same { for y in diff { wins += x > y ? 1 : (x == y ? 0.5 : 0) } }
        return wins / Double(same.count * diff.count)
    }
    let f2 = { (x: Double) in String(format: "%.2f", x) }
    report += """

    ### Why word vectors

    With no folders, notes can only be compared one pair at a time, and that's much harder than comparing a note with a whole folder. AUC is the chance that two notes from the same folder look more alike than two from different folders: 0.5 is a coin flip, 1.0 is perfect. Both rows mix in word overlap at the shipped weight.

    | Meaning from | Everything at once | Held-out check pile |
    |---|---|---|
    | Apple's sentence model (what the sorter uses) | \(f2(auc(pileAll, embedder))) | \(f2(auc(pileCheck, embedder))) |
    | Apple's word vectors, summed (what starter folders use) | \(f2(auc(pileAll, wordVectors))) | \(f2(auc(pileCheck, wordVectors))) |

    """
}

print(report)
if let i = CommandLine.arguments.firstIndex(of: "--write"), i + 1 < CommandLine.arguments.count {
    try report.write(toFile: CommandLine.arguments[i + 1], atomically: true, encoding: .utf8)
}
