import AppKit
import Observation
import StickiesCore

/// The app's view of the notes. Edits apply in memory at once; disk work
/// goes through one serial queue in the background, so the UI never waits.
@MainActor @Observable
final class Board {
    private(set) var library = Library.empty()
    private(set) var loaded = false
    var selectedFolderID: Folder.ID?
    var selectedNoteID: Note.ID?
    var editingNoteID: Note.ID?
    var searchText = ""
    private(set) var suggestions: [Note.ID: SortOutcome] = [:]
    private(set) var isSorting = false
    var dismissedSuggestions: Set<Note.ID> = []
    var dismissedStale: Set<Note.ID> = []
    var errorMessage: String?
    var renamingFolderID: Folder.ID?
    /// Ghost cards on their way to a folder after you accept a suggestion.
    private(set) var flights: [Flight] = []
    /// Counts notes landing in each folder, so its row can give a small bounce.
    private(set) var landings: [String: Int] = [:]
    /// Where cards and folder rows are on screen, for the flights. Not
    /// observed: it changes on every scroll and nothing needs to redraw.
    let frames = FrameBook()

    let root: URL
    let isDemo: Bool
    private let disk: NoteDisk
    private let jobs: AsyncStream<Job>.Continuation
    private var saveTasks: [Note.ID: Task<Void, Never>] = [:]
    private var sortTask: Task<Void, Never>?
    private var sortJob: Task<Void, Never>?
    private let embedder = AppleSentenceEmbedder()

    private enum Job: Sendable {
        case ops([DiskOp])
        case reload
        case barrier(CheckedContinuation<Void, Never>)
    }

    init(root: URL, isDemo: Bool) {
        self.root = root
        self.isDemo = isDemo
        let disk = NoteDisk(root: root)
        self.disk = disk
        let (stream, continuation) = AsyncStream<Job>.makeStream()
        jobs = continuation
        // Load the language data now, while the board appears, so the first
        // sort doesn't spend its first second or two on it.
        let embedder = embedder
        Task.detached(priority: .utility) { Sorter.warmUp(embedder) }
        Task.detached(priority: .userInitiated) { [weak self] in
            for await job in stream {
                switch job {
                case let .ops(ops):
                    let failures = await disk.run(ops)
                    if let first = failures.first {
                        await self?.report("Couldn't save a change: \(first.message). Your text is still here; try again or check the notes folder.")
                    }
                case .reload:
                    do {
                        let fresh = try LibraryLoader.load(root: root)
                        await self?.adopt(fresh)
                    } catch {
                        await self?.report("Couldn't read the notes folder: \(error.localizedDescription)")
                    }
                case let .barrier(c):
                    c.resume()
                }
            }
        }
    }

    // MARK: Settings

    var staleDays: Int {
        let v = UserDefaults.standard.integer(forKey: "staleDays")
        return v == 0 ? Staleness.defaultDays : v
    }

    var strictness: Double { UserDefaults.standard.double(forKey: "sortStrictness") }

    // MARK: Loading

    func reload() { jobs.yield(.reload) }

    private func adopt(_ fresh: Library) {
        library = library.merged(withDisk: fresh)
        if selectedFolderID == nil || library.folder(selectedFolderID!) == nil {
            selectedFolderID = library.inbox.id
            // For documentation screenshots: -folder Cooking, -search miso.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-folder"), i + 1 < args.count, let f = library.folder(named: args[i + 1]) {
                selectedFolderID = f.id
            }
            if let i = args.firstIndex(of: "-search"), i + 1 < args.count { searchText = args[i + 1] }
        }
        loaded = true
        scheduleSort()
    }

    private func report(_ message: String) { errorMessage = message }

    private func apply(_ ops: [DiskOp]) {
        guard !ops.isEmpty else { return }
        jobs.yield(.ops(ops))
    }

    /// Write everything and wait until it's on disk (quitting, tests).
    func flushAndWait() async {
        for t in saveTasks.values { t.cancel() }
        saveTasks = [:]
        apply(library.persistAll())
        await withCheckedContinuation { jobs.yield(.barrier($0)) }
    }

    func flush() {
        for t in saveTasks.values { t.cancel() }
        saveTasks = [:]
        apply(library.persistAll())
    }

    // MARK: Derived

    var selectedFolder: Folder? { selectedFolderID.flatMap(library.folder) ?? library.folders.first }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Matches across every folder, in folder order.
    var searchResults: [(note: Note, folder: Folder)] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return library.folders.flatMap { f in
            f.notes.filter { $0.text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }.map { ($0, f) }
        }
    }

    var hasAnyNotes: Bool { library.folders.contains { !$0.notes.isEmpty } }

    func isStale(_ note: Note, in folder: Folder) -> Bool {
        !dismissedStale.contains(note.id) && Staleness.isStale(note, in: folder.kind, days: staleDays)
    }

    func staleCount(in folder: Folder) -> Int { folder.notes.filter { isStale($0, in: folder) }.count }

    /// Suggestion to show on a card (Inbox only, not dismissed).
    func suggestion(for note: Note) -> SortOutcome? {
        guard !dismissedSuggestions.contains(note.id), library.folderOf(note: note.id)?.kind == .inbox else { return nil }
        return suggestions[note.id]
    }

    var suggestedMoves: [(Note.ID, String)] {
        library.inbox.notes.compactMap { n in suggestion(for: n)?.folder.map { (n.id, $0) } }
    }

    // MARK: Notes

    func newNote(text: String = "") {
        searchText = ""
        guard var folder = selectedFolder else { return }
        if folder.kind == .archive { folder = library.inbox; selectedFolderID = folder.id }
        guard let id = library.createNote(in: folder.id, text: text) else { return }
        selectedNoteID = id
        editingNoteID = id
        if !text.isEmpty { scheduleSave(id) }
    }

    func setText(_ id: Note.ID, _ text: String) {
        library.setText(id, text)
        suggestions[id] = nil
        dismissedStale.remove(id)
        scheduleSave(id)
    }

    private func scheduleSave(_ id: Note.ID) {
        saveTasks[id]?.cancel()
        saveTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.saveTasks[id] = nil
            self.apply(self.library.persist(id))
            if self.library.folderOf(note: id)?.kind == .inbox { self.scheduleSort() }
        }
    }

    func beginEditing(_ id: Note.ID) {
        if let current = editingNoteID, current != id { endEditing() }
        selectedNoteID = id
        editingNoteID = id
    }

    func endEditing() {
        guard let id = editingNoteID else { return }
        editingNoteID = nil
        saveTasks[id]?.cancel()
        saveTasks[id] = nil
        apply(library.persist(id))
        let discard = library.discardIfBlank(id)
        if library.note(id) == nil {
            apply(discard)
            if selectedNoteID == id { selectedNoteID = nil }
        }
    }

    func delete(_ id: Note.ID) {
        if editingNoteID == id { editingNoteID = nil }
        saveTasks[id]?.cancel()
        let neighbor = neighbor(of: id)
        apply(library.persist(id))
        apply(library.trash(id))
        selectedNoteID = neighbor
    }

    func move(_ id: Note.ID, to folderID: Folder.ID, at position: Int? = nil) {
        if editingNoteID == id { endEditing() }
        saveTasks[id]?.cancel()
        saveTasks[id] = nil
        let neighbor = library.folderOf(note: id)?.id == folderID ? id : neighbor(of: id)
        apply(library.move(id, to: folderID, at: position))
        suggestions[id] = nil
        dismissedStale.remove(id)
        if selectedNoteID == id { selectedNoteID = neighbor }
        scheduleSort()
    }

    func move(_ id: Note.ID, toFolderNamed name: String) {
        guard let f = library.folder(named: name) else { return }
        move(id, to: f.id)
    }

    func archive(_ id: Note.ID) { move(id, to: library.archive.id) }

    /// Drop `id` where `target` is, within the same folder.
    func reorder(_ id: Note.ID, before target: Note.ID) {
        guard id != target, let t = library.location(of: target), let s = library.location(of: id) else { return }
        if s.folder != t.folder {
            move(id, to: library.folders[t.folder].id, at: t.note)
        } else {
            apply(library.reorder(id, to: t.note))
        }
    }

    private func neighbor(of id: Note.ID) -> Note.ID? {
        guard let l = library.location(of: id) else { return nil }
        let notes = library.folders[l.folder].notes
        if l.note + 1 < notes.count { return notes[l.note + 1].id }
        if l.note > 0 { return notes[l.note - 1].id }
        return nil
    }

    /// Arrow-key selection within the current grid.
    func moveSelection(by delta: Int) {
        guard let folder = selectedFolder, !folder.notes.isEmpty else { return }
        guard let current = selectedNoteID, let i = folder.notes.firstIndex(where: { $0.id == current }) else {
            selectedNoteID = folder.notes.first?.id
            return
        }
        selectedNoteID = folder.notes[min(max(i + delta, 0), folder.notes.count - 1)].id
    }

    // MARK: Folders

    func select(_ folderID: Folder.ID) {
        guard folderID != selectedFolderID else { return }
        endEditing()
        flush()
        selectedFolderID = folderID
        selectedNoteID = nil
        searchText = ""
    }

    func newFolder() {
        endEditing()
        let (id, ops) = library.createFolder(named: "New Folder")
        apply(ops)
        selectedFolderID = id
        selectedNoteID = nil
        searchText = ""
        renamingFolderID = id
    }

    func renameFolder(_ id: Folder.ID, to name: String) {
        apply(library.renameFolder(id, to: name))
        renamingFolderID = nil
        scheduleSort()
    }

    func setColor(_ id: Folder.ID, _ color: FolderColor) { apply(library.setColor(id, color)) }

    func deleteFolder(_ id: Folder.ID) {
        endEditing()
        flush()
        apply(library.deleteFolder(id))
        if selectedFolderID == id { selectedFolderID = library.inbox.id }
        scheduleSort()
    }

    func moveFolder(_ id: Folder.ID, to position: Int) { apply(library.moveFolder(id, to: position)) }

    // MARK: Sorting

    /// Recompute Inbox suggestions shortly after things settle.
    func scheduleSort() {
        sortTask?.cancel()
        sortJob?.cancel()
        sortTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.sortInbox()
        }
    }

    func sortInbox() async {
        let notes = library.inbox.notes
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { (id: $0.id, text: $0.text) }
        let candidates = library.userFolders.map { SortCandidate(name: $0.name, notes: $0.notes.map(\.text)) }
        guard !notes.isEmpty else { suggestions = [:]; isSorting = false; return }
        let config = SorterConfig.standard.shifted(by: strictness)
        let embedder = embedder
        isSorting = true
        // Suggestions arrive a dozen notes at a time, top of the Inbox first,
        // so the cards you see fill in while the rest are worked out. Old
        // suggestions stay until their note's new one arrives: no flicker.
        let (batches, sink) = AsyncStream<[Note.ID: SortOutcome]>.makeStream()
        let job = Task.detached(priority: .userInitiated) {
            Sorter(config: config, embedder: embedder).suggest(notes: notes, folders: candidates) { sink.yield($0) }
            sink.finish()
        }
        sortJob = job
        for await batch in batches {
            guard !Task.isCancelled else { return }
            suggestions.merge(batch) { _, new in new }
        }
        guard !Task.isCancelled else { return }
        let current = Set(notes.map(\.id))
        suggestions = suggestions.filter { current.contains($0.key) }
        isSorting = false
    }

    func acceptSuggestion(_ id: Note.ID) {
        guard let name = suggestion(for: library.note(id) ?? Note(fileName: "", text: "", modified: .now))?.folder else { return }
        fly(id, to: name)
        move(id, toFolderNamed: name)
    }

    func acceptAllSuggestions() {
        let moves = suggestedMoves
        for (i, (id, name)) in moves.enumerated() { fly(id, to: name, delay: Double(min(i, 12)) * 0.03) }
        for (id, name) in moves { move(id, toFolderNamed: name) }
    }

    /// Sends a ghost of the card to its folder row, so you see where it went.
    /// Only for cards on screen, and never with Reduce Motion on.
    private func fly(_ id: Note.ID, to folderName: String, delay: Double = 0) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let from = frames.cards[id], from.intersects(frames.board),
              let to = frames.folders[folderName],
              let note = library.note(id), let source = library.folderOf(note: id),
              let target = library.folder(named: folderName) else { return }
        let flight = Flight(folder: folderName, from: from, to: to, title: note.title.isEmpty ? "Untitled" : note.title,
                            fromColor: source.color, toColor: target.color, delay: delay)
        flights.append(flight)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Flight.duration + delay))
            self?.landings[folderName, default: 0] += 1
            self?.flights.removeAll { $0.id == flight.id }
        }
    }

    func dismissSuggestion(_ id: Note.ID) { dismissedSuggestions.insert(id) }

    /// Notes in a folder minus cards still flying there, so the sidebar count
    /// ticks up as each one lands.
    func shownCount(_ folder: Folder) -> Int {
        folder.notes.count - flights.filter { $0.folder == folder.name }.count
    }

    // MARK: Import and samples

    func importFromAppleStickies() async -> String {
        do {
            let stickies = try await Task.detached { try StickiesImporter.read() }.value
            let (added, ops) = library.addImported(stickies)
            apply(ops)
            scheduleSort()
            if stickies.isEmpty { return "Apple Stickies has no notes to copy." }
            if added == 0 { return "Already imported. All \(stickies.count) Apple Stickies notes are in your Inbox or filed." }
            let skipped = stickies.count - added
            return "Copied \(added) notes into Inbox" + (skipped > 0 ? " (\(skipped) blank or already imported)." : ".") + " Apple Stickies wasn't changed."
        } catch {
            return error.localizedDescription
        }
    }

    func addSampleNotes() async {
        flush()
        let root = root
        await withCheckedContinuation { jobs.yield(.barrier($0)) }
        do {
            try await Task.detached { try SampleSet.load().write(to: root) }.value
        } catch {
            report("Couldn't add sample notes: \(error.localizedDescription)")
        }
        reload()
    }

    func revealInFinder(_ folder: Folder? = nil) {
        let url = folder.map { root.appendingPathComponent($0.name, isDirectory: true) } ?? root
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

/// A card on its way to a folder row.
struct Flight: Identifiable {
    static let duration = 0.3
    let id = UUID()
    let folder: String
    let from: CGRect
    let to: CGRect
    let title: String
    let fromColor: FolderColor
    let toColor: FolderColor
    let delay: Double
}

/// Window positions of cards, folder rows and the visible board, in global
/// coordinates. Plain storage, deliberately not observed.
@MainActor final class FrameBook {
    var cards: [Note.ID: CGRect] = [:]
    var folders: [String: CGRect] = [:]
    var board: CGRect = .zero
}
