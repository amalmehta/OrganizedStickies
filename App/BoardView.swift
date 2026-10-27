import SwiftUI
import StickiesCore

struct BoardView: View {
    @Environment(Board.self) private var board
    @Environment(\.textScale) private var scale
    @FocusState private var gridFocused: Bool
    @State private var columns = 3

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
        .background(Theme.window)
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.minCard * scale, maximum: 320 * scale), spacing: Self.spacing)],
                              spacing: Self.spacing) {
                        ForEach(folder.notes) { note in
                            StickyCard(note: note, folder: folder)
                                .id(note.id)
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .padding(.top, 4)
                    .animation(.easeOut(duration: 0.2), value: folder.notes.map(\.id))
                }
                .scrollContentBackground(.hidden)
                .onChange(of: board.selectedNoteID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) } }
                }
            }
            .onAppear { columns = Self.columnCount(width: geo.size.width, scale: scale) }
            .onChange(of: geo.size.width) { _, w in columns = Self.columnCount(width: w, scale: scale) }
        }
        .contentShape(Rectangle())
        .onTapGesture { board.endEditing(); gridFocused = true }
        .focusable()
        .focusEffectDisabled()
        .focused($gridFocused)
        .onKeyPress(.leftArrow) { arrow(-1) }
        .onKeyPress(.rightArrow) { arrow(1) }
        .onKeyPress(.upArrow) { arrow(-columns) }
        .onKeyPress(.downArrow) { arrow(columns) }
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

    private func arrow(_ delta: Int) -> KeyPress.Result {
        guard board.editingNoteID == nil else { return .ignored }
        board.moveSelection(by: delta)
        return .handled
    }

    static func columnCount(width: CGFloat, scale: Double) -> Int {
        max(1, Int((width - 48 + spacing) / (minCard * scale + spacing)))
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
                if board.isSorting && board.suggestedMoves.isEmpty {
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
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: BoardView.minCard * scale, maximum: 320 * scale), spacing: 16)], spacing: 16) {
                        ForEach(results, id: \.note.id) { r in
                            StickyCard(note: r.note, folder: r.folder, showFolder: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}
