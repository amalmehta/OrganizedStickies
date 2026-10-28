import SwiftUI
import StickiesCore

struct BoardView: View {
    @Environment(Board.self) private var board
    @Environment(\.textScale) private var scale
    @FocusState private var gridFocused: Bool
    @State private var memory = ColumnMemory()

    static let minCard: CGFloat = 210
    static let spacing: CGFloat = 16

    var body: some View {
        Group {
            if !board.loaded {
                // First read of the notes folder; usually a blink.
                Color.clear
            } else if board.isSearching {
                SearchResultsView()
            } else if let folder = board.selectedFolder {
                folderBoard(folder)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Backdrop().ignoresSafeArea() }
    }

    @ViewBuilder
    private func folderBoard(_ folder: Folder) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BoardHeader(folder: folder)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 10)
            if folder.notes.isEmpty {
                if !board.hasAnyNotes && folder.kind == .inbox {
                    WelcomeView()
                } else {
                    FolderEmptyState(folder: folder)
                }
            } else {
                grid(folder)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            // Notes dropped on empty board space go to the end of this folder;
            // text dragged in from another app becomes a new note.
            var handled = false
            for item in items {
                if let id = NoteDragID.parse(item) {
                    board.move(id, to: folder.id, at: folder.notes.count)
                    handled = true
                } else if !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    board.newNote(text: item)
                    board.endEditing()
                    handled = true
                }
            }
            return handled
        }
    }

    private func grid(_ folder: Folder) -> some View {
        GeometryReader { geo in
            let count = Self.columnCount(width: geo.size.width, scale: scale)
            let width = Self.columnWidth(total: geo.size.width, count: count, scale: scale)
            let columns = memory.columns(for: folder, count: count, width: width, scale: scale,
                                         hasFooterNote: { folder.kind == .inbox || board.isStale($0, in: folder) })
            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: Self.spacing) {
                        ForEach(columns.indices, id: \.self) { c in
                            LazyVStack(spacing: Self.spacing) {
                                ForEach(columns[c]) { note in
                                    StickyCard(note: note, folder: folder) { dropped in
                                        for id in dropped { memory.put(id, inColumnOf: note.id) }
                                    }
                                    .id(note.id)
                                    .accessibilitySortPriority(memory.readingPriority(note.id))
                                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                                }
                            }
                            .frame(width: width)
                        }
                    }
                    // VoiceOver reads cards in board order, not column by column.
                    .accessibilityElement(children: .contain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .padding(.top, 4)
                    .animation(.snappy(duration: 0.22), value: folder.notes.map(\.id))
                }
                .scrollContentBackground(.hidden)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { board.frames.board = $0 }
                .onChange(of: board.selectedNoteID) { _, id in
                    if let id { withAnimation(.snappy(duration: 0.2)) { proxy.scrollTo(id) } }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { board.endEditing(); gridFocused = true }
        .focusable()
        .focusEffectDisabled()
        .focused($gridFocused)
        .onKeyPress(.leftArrow) { arrow(.left) }
        .onKeyPress(.rightArrow) { arrow(.right) }
        .onKeyPress(.upArrow) { arrow(.up) }
        .onKeyPress(.downArrow) { arrow(.down) }
        .onKeyPress(.return) {
            guard board.editingNoteID == nil, let id = board.selectedNoteID else { return .ignored }
            board.beginEditing(id)
            return .handled
        }
        .onAppear { gridFocused = true }
        .onChange(of: board.editingNoteID) { _, id in if id == nil { gridFocused = true } }
        // Picking a folder puts the keyboard on its notes, so arrows and Return
        // work straight away (Tab only reaches the grid when Keyboard
        // navigation is on in System Settings).
        .onChange(of: board.selectedFolderID) { _, _ in gridFocused = true }
    }

    private func arrow(_ direction: ColumnMemory.Direction) -> KeyPress.Result {
        guard board.editingNoteID == nil, let folder = board.selectedFolder, !folder.notes.isEmpty else { return .ignored }
        // Nothing selected yet: any arrow picks the first note.
        guard let current = board.selectedNoteID, folder.notes.contains(where: { $0.id == current }) else {
            board.selectedNoteID = folder.notes.first?.id
            return .handled
        }
        if let next = memory.neighbor(of: current, direction) { board.selectedNoteID = next }
        return .handled
    }

    static func columnCount(width: CGFloat, scale: Double) -> Int {
        max(1, Int((width - 48 + spacing) / (minCard * scale + spacing)))
    }

    /// Columns share the width, up to 320 points each (wider cards read badly).
    static func columnWidth(total: CGFloat, count: Int, scale: Double) -> CGFloat {
        let fit = (total - 48 - CGFloat(count - 1) * spacing) / CGFloat(count)
        return max(minCard * scale * 0.8, min(320 * scale, fit))
    }
}

/// Which column each card sits in, kept while you work so that moving one
/// card out doesn't send the cards after it hopping between columns. Starts
/// fresh when you switch folders or the window changes how many columns fit.
@MainActor final class ColumnMemory {
    enum Direction { case up, down, left, right }

    private var key: (folder: Folder.ID, count: Int)?
    private var placed: [Note.ID: Int] = [:]
    private var laidOut: [[Note.ID]] = []
    private var top: [Note.ID: Double] = [:]
    private var order: [Note.ID: Int] = [:]

    func columns(for folder: Folder, count: Int, width: CGFloat, scale: Double, hasFooterNote: (Note) -> Bool) -> [[Note]] {
        if key?.folder != folder.id || key?.count != count {
            placed = [:]
            key = (folder.id, count)
        }
        let ids = folder.notes.map(\.id)
        let heights = folder.notes.map { CardHeight.estimate($0, width: width, scale: scale, hasFooterNote: hasFooterNote($0)) }
        placed = ColumnPacking.assign(ids: ids, heights: heights, columns: count, keep: placed)
        laidOut = ColumnPacking.columns(ids: ids, assignment: placed, count: count)
        let height = Dictionary(uniqueKeysWithValues: zip(ids, heights))
        top = [:]
        for column in laidOut {
            var y = 0.0
            for id in column { top[id] = y; y += (height[id] ?? 0) + BoardView.spacing }
        }
        order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let byID = Dictionary(uniqueKeysWithValues: folder.notes.map { ($0.id, $0) })
        return laidOut.map { $0.compactMap { byID[$0] } }
    }

    /// A dropped note joins the column of the card it was dropped on.
    func put(_ id: Note.ID, inColumnOf other: Note.ID) {
        if let c = placed[other] { placed[id] = c }
    }

    /// Higher reads first, so VoiceOver follows the notes' order.
    func readingPriority(_ id: Note.ID) -> Double {
        Double(order.count - (order[id] ?? order.count))
    }

    /// Up and down stay in the column; left and right go to the card at about
    /// the same height in the next column.
    func neighbor(of id: Note.ID, _ direction: Direction) -> Note.ID? {
        guard let c = laidOut.firstIndex(where: { $0.contains(id) }), let i = laidOut[c].firstIndex(of: id) else { return nil }
        switch direction {
        case .up: return i > 0 ? laidOut[c][i - 1] : nil
        case .down: return i + 1 < laidOut[c].count ? laidOut[c][i + 1] : nil
        case .left, .right:
            var n = direction == .left ? c - 1 : c + 1
            while laidOut.indices.contains(n) && laidOut[n].isEmpty { n += direction == .left ? -1 : 1 }
            guard laidOut.indices.contains(n) else { return nil }
            let y = top[id] ?? 0
            return laidOut[n].min { abs((top[$0] ?? 0) - y) < abs((top[$1] ?? 0) - y) }
        }
    }
}

struct BoardHeader: View {
    @Environment(Board.self) private var board
    let folder: Folder
    @State private var showHowItWorks = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(Theme.quiet)
            }
            Spacer()
            if folder.kind == .inbox && !folder.notes.isEmpty {
                if board.isSorting {
                    ProgressView().controlSize(.small)
                }
                Button { showHowItWorks.toggle() } label: {
                    Label("How sorting works", systemImage: "questionmark.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.quiet)
                .help("How sorting works")
                .popover(isPresented: $showHowItWorks, arrowEdge: .bottom) { HowSortingWorks().padding(18).frame(width: 380) }
                let n = board.suggestedMoves.count
                if n > 0 {
                    Button { board.acceptAllSuggestions() } label: {
                        Label("Move \(n) Suggested", systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Move every note with a suggestion to its folder (⇧⌘Y)")
                    .accessibilityIdentifier("moveAllSuggested")
                }
            }
        }
    }

    private var subtitle: String {
        let count = folder.notes.count
        let notes = "\(count) \(count == 1 ? "note" : "notes")"
        switch folder.kind {
        case .inbox:
            guard count > 0 else { return "New notes land here." }
            if board.library.userFolders.isEmpty { return "\(notes) · make a folder to start sorting" }
            let n = board.suggestedMoves.count
            if n == 0 && board.isSorting { return "\(notes) · sorting…" }
            if n > 0 && board.isSorting { return "\(notes) · \(n) with a suggested folder so far · sorting…" }
            return n > 0 ? "\(notes) · \(n) with a suggested folder. Nothing moves until you click." : "\(notes) · no confident suggestions right now"
        case .archive:
            return count > 0 ? "\(notes) you're done with. Still searchable." : "Notes you're done with."
        case .user:
            let stale = board.staleCount(in: folder)
            return stale > 0 ? "\(notes) · \(stale) untouched for \(board.staleDays)+ days" : notes
        }
    }
}

/// Teaches the idea behind the suggestions, short first.
struct HowSortingWorks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How sorting works")
                .font(.system(size: 15, weight: .semibold, design: .serif))
            Text("Each Inbox note is compared with the notes already in each folder, in two ways:")
            VStack(alignment: .leading, spacing: 6) {
                Label("**Shared words.** Rare words count more than common ones. “Neuropixels” says a lot; “the” says nothing.", systemImage: "textformat")
                Label("**Similar meaning.** Apple's on-device language model places “braise short ribs” near “slow-cook lamb” even with no words in common.", systemImage: "point.3.connected.trianglepath.dotted")
            }
            Text("A folder is suggested only when it clearly beats the others. Short notes like “call mom” usually get **No clear match**. That's on purpose, because a wrong guess is worse than none.")
            Text("Everything runs on this Mac. Nothing is sent anywhere, and nothing moves until you click.")
                .foregroundStyle(Theme.quiet)
            Text("**Rule of thumb:** a sorter is only as good as what it can compare with. A folder with a few clear notes in it attracts the right new ones.")
                .foregroundStyle(Theme.quiet)
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SearchResultsView: View {
    @Environment(Board.self) private var board
    @Environment(\.textScale) private var scale

    var body: some View {
        let results = board.searchResults
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Search")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                Text("\(results.count) \(results.count == 1 ? "note matches" : "notes match") “\(board.searchText)” across all folders")
                    .font(.callout)
                    .foregroundStyle(Theme.quiet)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 10)
            if results.isEmpty {
                EmptyStateView(picture: AnyView(NoteStackPicture(color: .paper)),
                               title: "No notes match",
                               message: "Search looks at every word in every folder, Archive included. Try a shorter word.")
            } else {
                GeometryReader { geo in
                    let count = BoardView.columnCount(width: geo.size.width, scale: scale)
                    let width = BoardView.columnWidth(total: geo.size.width, count: count, scale: scale)
                    let ids = results.map(\.note.id)
                    let heights = results.map { CardHeight.estimate($0.note, width: width, scale: scale, hasFooterNote: false) }
                    let columns = ColumnPacking.columns(ids: ids, assignment: ColumnPacking.assign(ids: ids, heights: heights, columns: count), count: count)
                    let byID = Dictionary(uniqueKeysWithValues: results.map { ($0.note.id, $0) })
                    let rank = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
                    ScrollView {
                        HStack(alignment: .top, spacing: BoardView.spacing) {
                            ForEach(columns.indices, id: \.self) { c in
                                LazyVStack(spacing: BoardView.spacing) {
                                    ForEach(columns[c], id: \.self) { id in
                                        if let r = byID[id] {
                                            StickyCard(note: r.note, folder: r.folder, showFolder: true)
                                                .accessibilitySortPriority(Double(ids.count - (rank[id] ?? 0)))
                                        }
                                    }
                                }
                                .frame(width: width)
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }
}
